# HTTP client

Every request the app sends goes through `ApiClient` (`lib/infrastructure/http/api_client.dart`) and its Dio interceptor chain, in this order: connectivity, auth, token refresh, idempotency, resilience, cache, developer console and logging, with the mock interceptor last in dev and test builds.
This page describes when the chain repeats a request and when it answers one from its cache.
The rules for Studio's endpoints are in [architecture.md](architecture.md#talking-to-studio), the mock layer in [mock-architecture.md](mock-architecture.md), and the certificate checks in [security.md](security.md#certificate-pinning).

## Retries

`ResilienceInterceptor` repeats a `GET` that failed with a timeout, a connection error, or a 502, 503 or 504 without a Studio error code in its body, up to three times.
No other method is repeated: a `POST` to Studio may run a statement, and the other methods change something on the server, so the caller gets the error, an `Idempotency-Key` header or not.

An answer whose body carries a Studio error code (`{"error": ..., "code": ...}`) is Studio's own answer, such as a 503 `GOVERNANCE_UNAVAILABLE` or `IDENTITY_PROVIDER_UNAVAILABLE`, or a 504 `TIMEOUT_ERROR`.
It reaches the repository after one request, so the user sees what Studio said, and it is never repeated.
A status the caller accepts (`ApiClient.get` with `acceptedStatuses`, which `GET /api/ready` uses for its 503 answers) is a response, not an error, so it is neither repeated nor counted.

After five failures in a row the interceptor opens the endpoint's circuit and refuses its requests for 30 seconds with `CircuitBreakerOpenException`.
Only a timeout, a connection error and a 5xx without a Studio error code count as failures.
A 4xx, an answer with a Studio error code at any status, an offline rejection and a TLS failure do not, so an endpoint that keeps answering `GOVERNANCE_UNAVAILABLE` never opens its circuit and the user keeps seeing that Studio is temporarily unavailable.

## Idempotency keys

`IdempotencyInterceptor` attaches `Idempotency-Key: <uuid-v4>` to a `POST`, `PUT` or `PATCH` whose caller opts in:

```dart
await apiClient.post<Item>('/items', item, idempotent: true);
await apiClient.put<Item>('/items', item, pathParams: '42', idempotent: true);
await apiClient.patch<Item>('/items', item, pathParams: '42', idempotent: true);
```

The header is a contract, not a guarantee: the server must deduplicate by it (the IETF draft `idempotency-key-header`, with Stripe as the worked example).
`ResilienceInterceptor` never repeats a request that carries it, since it repeats only a `GET`.
No request the app sends opts in.

Once generated, the key is kept in `RequestOptions.extra['_idempotency_key']` and reused on every later pass, which covers the resend by `TokenRefreshInterceptor` after a 401 and a refresh.
`GET`, `HEAD`, `OPTIONS` and `DELETE` never get the header.

## Response cache

`CacheInterceptor` stores successful `GET` responses and answers from them by the request's `CachePolicy` (`options.extra['cachePolicy']`, `networkFirst` by default, `networkOnly` for Studio's live endpoints):

| Policy | Behavior |
| --- | --- |
| `networkFirst` | Sends the request; answers from the cache only when the server cannot be reached |
| `cacheFirst` | Answers from a fresh entry without sending the request; otherwise behaves as `networkFirst` |
| `cacheOnly` | Answers from a fresh entry or fails with "No cached data available"; it never reaches the network, so neither being offline nor an open circuit stops it |
| `networkOnly` | Never reads or writes the cache |

Studio's live endpoints are `networkOnly` unless the request names another policy: `/connections/managed`, `/connections/policy`, `/auth/me`, `/health`, `/ready` and every `/db/*` path.
Their answers carry grants, policy, identity and database state that may change at any moment, and a cached list would show a connection whose grant was revoked as available.
Offline, such a `GET` fails with a network error; a list that should stay on screen is held in BLoC state and shown as stale, never served as fresh by the HTTP layer.

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

## LibreDB Platform

Platform mode talks to LibreDB Platform's bearer API through `PlatformApiClient` (`lib/infrastructure/platform/platform_api_client.dart`), its own DI type next to the Studio `ApiClient`, so a Studio repository can never be given the Platform client, and the reverse.
It wraps an `ApiClient` built with an `ApiTarget` (`lib/infrastructure/http/api_target.dart`): the base URL and pins of `AppConfig.platform` (`PLATFORM_API_URL`, `PLATFORM_CERT_PINS`) and `PlatformErrorEnvelope`; the Studio client uses `StudioErrorEnvelope` and is unchanged.
The interceptor chain is the same, with the account refusal interceptor; both clients share the one token rotation.
A Studio session uses this client too, on Platform's requester routes alone, when the user asks for access to a connection ([platform.md](platform.md#access-requests-from-a-studio-session)).

- **Envelope.** Platform's error body is `{"error":{"code","message","fieldErrors"?}}`.
  `PlatformErrorEnvelope` reads `error.code` and the keys of `error.fieldErrors` (`BadRequestException.fieldErrorKeys`).
  The exception text carries only the status, the code and the field keys, never Platform's `message` or a field's message, which can name a user; there is no `serverMessage`.
- **Session.** A 401 `BEARER_INVALID` starts one refresh, and a second one after it ends the session as expired (`lib/infrastructure/platform/platform_session_policy.dart`).
  A 401 without Platform's envelope reaches the caller and keeps the session, and a 502 or 503 never ends it.
- **Account refusal.** A 403 `ADMIN_ROLE_REQUIRED` or `LICENSE_ADMIN_SEATS` is reported to `PlatformAccountRefusalCubit`, only under a signed-in Platform session.
- **Methods.** `PlatformApiClient` exposes `get`, `post`, `put`, `patch` and `delete`, each one path relative to Platform's `/api`, with `pathParams` appended as further segments.
  `post` forwards `sensitiveKeys` to `ApiClient.post`, so a body key such as an access request's `reason` is masked in the verbose log and the dev console, and it never passes the `idempotent` opt-in, so a write is never sent twice.
- **Retries.** `ResilienceInterceptor` reads the code through the client's envelope, so a coded Platform answer, such as a 503 `DIRECTORY_UNAVAILABLE` or a 502 `KEYCLOAK_AUTH_ERROR`, is sent once and never counted against the circuit breaker; only a `GET` is ever repeated.
- **Cache.** Every path under `/v1/` and the liveness probe `/health/live` are `networkOnly`, whatever the request names, so a Platform answer is never stored or served from the cache, and an offline Platform never reads as live.
- **No target.** In a build without `PLATFORM_API_URL` every call fails with `PlatformNotConfiguredException` and no request is sent.

The contract and the error table are in [platform.md](platform.md).
