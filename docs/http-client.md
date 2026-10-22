# HTTP client

Every request the app sends goes through `ApiClient` (`lib/infrastructure/http/api_client.dart`) and its Dio interceptor chain, in this order: connectivity, auth, token refresh, idempotency, resilience, cache, developer console and logging, with the mock interceptor last in dev and test builds.
This page describes when the chain repeats a request and when it answers one from its cache.
The rules for Studio's endpoints are in [architecture.md](architecture.md#talking-to-studio), the mock layer in [mock-architecture.md](mock-architecture.md), and the certificate checks in [security.md](security.md#certificate-pinning).

## Retries

`ResilienceInterceptor` repeats a request that failed with a timeout, a connection error or a 502, 503 or 504, up to three times, and only when the request is safe to send twice.
`GET`, `HEAD`, `OPTIONS`, `PUT` and `DELETE` are idempotent by HTTP semantics and are repeated.
A `POST` or `PATCH` may already have been processed by the server, so it is repeated only when it carries an `Idempotency-Key` header; without one, the caller gets the error.
Only `UserRepository.create` (`POST /admin/users`, inherited from the template, not a Studio endpoint) carries that header; no request to a Studio endpoint does, so nothing that runs a statement is ever repeated.

After five failures in a row the interceptor opens the endpoint's circuit and refuses its requests for 30 seconds with `CircuitBreakerOpenException`.

## Idempotency keys

`IdempotencyInterceptor` attaches `Idempotency-Key: <uuid-v4>` to a `POST`, `PUT` or `PATCH` whose caller opts in:

```dart
await apiClient.post<User>('/admin/users', user, idempotent: true);
await apiClient.put<User>('/admin/users', user, pathParams: '42', idempotent: true);
await apiClient.patch<User>('/admin/users', user, pathParams: '42', idempotent: true);
```

The header is a contract, not a guarantee: the server must deduplicate by it (the IETF draft `idempotency-key-header`, with Stripe as the worked example).
Against a server that ignores it, opting in is worse than leaving it off, because the key is what lets `ResilienceInterceptor` repeat a `POST` or `PATCH`, and every repeat the server processes creates another record.
`UserRepository.create` (`POST /admin/users`, inherited from the template, not a Studio endpoint) opts in.
No request to a Studio endpoint opts in, so no statement is ever repeated.

Once generated, the key is kept in `RequestOptions.extra['_idempotency_key']` and reused on every later pass, which covers both a `ResilienceInterceptor` retry and the resend by `TokenRefreshInterceptor` after a 401 and a refresh.
`GET`, `HEAD`, `OPTIONS` and `DELETE` never get the header.

## Response cache

`CacheInterceptor` stores successful `GET` responses and answers from them by the request's `CachePolicy` (`options.extra['cachePolicy']`, `networkFirst` by default):

| Policy | Behavior |
| --- | --- |
| `networkFirst` | Sends the request; answers from the cache only when the server cannot be reached |
| `cacheFirst` | Answers from a fresh entry without sending the request; otherwise behaves as `networkFirst` |
| `cacheOnly` | Answers from a fresh entry or fails with "No cached data available"; it never reaches the network, so neither being offline nor an open circuit stops it |
| `networkOnly` | Never reads or writes the cache |

An entry is fresh for its TTL, 5 minutes unless `options.extra['cacheTtl']` sets another.
Past its TTL an entry still answers a `GET` that cannot reach the server, with an `x-cache: stale` header, until it is 24 hours old (`CacheEntry.maxStaleAge`).
An entry read after that is deleted instead.
An answer from a fresh `cacheFirst` or `cacheOnly` entry carries `x-cache: hit`.

A `GET` cannot reach the server when the device is offline, or when the connection is refused, times out, or is closed or reset before the whole response arrived.
A response that dart:io cannot parse, such as one from a server that does not answer in HTTP, counts the same way, since dart:io reports it like a connection reset while the response is awaited.
Every other failure reaches the caller, a server error or a TLS failure included: an untrusted certificate is never answered from the cache.
So does an open circuit: a `GET` fails with `CircuitBreakerOpenException` even when a response is cached.

Ending the session, by a logout, the idle timeout or a token that cannot be refreshed, deletes every entry, and a clear that leaves some behind is logged as an error.
The response of a `GET` still on its way when the session ends is not stored, so it cannot answer the next user with the previous user's data.

The entries live in `SharedPreferences` next to the preferences, so `SharedPrefsCacheStorage` evicts: when it starts and before each write it deletes the entries past 24 hours, and before each write it deletes the oldest entries until the new one fits in 200 entries and 1,000,000 characters.
A write the store refuses is logged as an error with the key and the size, the entry is not cached, and the `GET` still succeeds.
