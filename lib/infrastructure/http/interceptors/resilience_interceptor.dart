import 'dart:math';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/security/sensitive_data_scrubber.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/circuit_breaker.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/cache_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/connectivity_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/transport_errors.dart';

/// Dio interceptor that combines **smart retry** with a **circuit breaker**
/// to improve resilience against transient failures.
///
/// **Retry logic:**
/// - Retryable errors: timeout, connection error, and an HTTP 502/503/504 without a Studio error code in its body.
///   A connection that closed before a full response header arrived is not retried.
/// - Only a GET is retried. A POST may run a statement on Studio, which a second copy would run again, and every
///   other method changes something on the server, so none of them is repeated, an `Idempotency-Key` header or not.
/// - An answer whose body carries a Studio error code (`{"error": ..., "code": ...}`, read by
///   [ApiClient.errorCodeOf]), such as a 503 `GOVERNANCE_UNAVAILABLE`, `AUDIT_UNAVAILABLE` or
///   `IDENTITY_PROVIDER_UNAVAILABLE`, or a 504 `TIMEOUT_ERROR`, is Studio's own answer: it passes through after one
///   request, so the repository can report what Studio said, and it does not count against the circuit breaker.
/// - Non-retryable: 400, 401, 403, 404, 422 pass through immediately.
/// - A request that [ConnectivityInterceptor] rejected because the device is offline (its error is a
///   [ConnectivityException]) passes through immediately and does not count against the circuit breaker: it was
///   never sent.
/// - A TLS failure (a certificate pin mismatch, a certificate the device does not trust, see [isTlsError]) passes
///   through immediately and does not count against the circuit breaker either: the handshake failed before the
///   request reached the server, and the user must see the insecure-connection error, not a circuit-open one.
/// - Max retries: 3, exponential backoff with jitter (200ms base).
/// - Respects the `Retry-After` header when present.
/// - Retries go through the adapter of the Dio given to [forDio], so they keep its certificate
///   pinning. An instance not made by [forDio] rejects a retry instead of sending it.
///
/// **Circuit breaker logic:**
/// - Each endpoint (path prefix) gets its own [CircuitBreaker] instance.
/// - Before a request: if the circuit is OPEN, rejects immediately with
///   [CircuitBreakerOpenException], with `callFollowingErrorInterceptor: true` so that the dev console and the HTTP
///   log record it. [CacheInterceptor] does not answer it, so a GET fails with it even when a response is cached,
///   although the circuit counts the lost connections and timeouts that the cache answers, each retry included: on a
///   network that cannot reach a healthy server, once [failureThreshold] attempts have failed, every request to the
///   endpoint, a cached GET included, fails for [cooldownDuration]. A GET that [CacheInterceptor] answers from the
///   cache alone (`CachePolicy.cacheOnly`) is let through: it never reaches the network, and its failure when nothing
///   is cached does not count against the circuit breaker.
/// - After a response: records success or failure.
/// - Only a failure that says the endpoint is unhealthy counts: a timeout, a connection error, or a 5xx without a
///   Studio error code. A 4xx, an answer with a Studio error code at any status, an offline rejection, a TLS failure
///   and the failure of a cacheOnly GET do not count, and neither records a success. Studio answering
///   `GOVERNANCE_UNAVAILABLE` on every poll therefore never opens the circuit: the user keeps seeing Studio's
///   'temporarily unavailable' instead of a circuit-open error.
///
/// **Bypass:** a request whose extra holds [bypassExtraKey] set to true is sent once, is never rejected by an open
/// circuit, and records neither a success nor a failure. Studio's health probes use it: their failure is the answer the
/// user must see, and a user's Retry must reach Studio as soon as it is back, not wait out a circuit the failed probes
/// opened.
///
/// Must be added to the interceptor chain AFTER [AuthInterceptor] so that
/// the auth token is present, and BEFORE [MockInterceptor] so that
/// resilience logic wraps the actual network call.
class ResilienceInterceptor extends Interceptor {
  static final _log = AppLogger.getLogger('ResilienceInterceptor');
  static final _random = Random();

  static final ResilienceInterceptor _instance = ResilienceInterceptor();
  static ResilienceInterceptor get instance => _instance;

  /// The extra key that sends a request past retries and the circuit breaker; see the class documentation.
  static const String bypassExtraKey = 'resilience.bypass';

  /// Whether [options] bypasses retries and the circuit breaker ([bypassExtraKey]).
  static bool isBypassed(RequestOptions options) => options.extra[bypassExtraKey] == true;

  /// Maximum number of retry attempts for retryable errors.
  final int maxRetries;

  /// Base delay for exponential backoff (doubles each attempt).
  final Duration baseDelay;

  /// Maximum random jitter added to each backoff delay.
  final Duration maxJitter;

  /// Per-endpoint circuit breakers.
  final Map<String, CircuitBreaker> _breakers;

  /// The [Dio] whose adapter sends retries; null unless this instance was made by [forDio].
  final Dio? _dio;

  /// Unmodifiable view of per-endpoint circuit breakers for monitoring.
  Map<String, CircuitBreaker> get circuitBreakers => Map.unmodifiable(_breakers);

  /// Reset all circuit breakers to closed state.
  void resetAll() {
    for (final breaker in _breakers.values) {
      breaker.reset();
    }
    _log.info('All circuit breakers reset');
  }

  /// Circuit breaker configuration.
  final int failureThreshold;
  final Duration cooldownDuration;

  ResilienceInterceptor({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 200),
    this.maxJitter = const Duration(milliseconds: 100),
    this.failureThreshold = 5,
    this.cooldownDuration = const Duration(seconds: 30),
  }) : _breakers = {},
       _dio = null;

  ResilienceInterceptor._forDio(ResilienceInterceptor source, Dio dio)
    : maxRetries = source.maxRetries,
      baseDelay = source.baseDelay,
      maxJitter = source.maxJitter,
      failureThreshold = source.failureThreshold,
      cooldownDuration = source.cooldownDuration,
      _breakers = source._breakers,
      _dio = dio;

  /// Returns an interceptor for [dio] that shares this instance's circuit breakers and retry policy
  /// and sends every retry through [dio]'s adapter, so retries keep its certificate pinning.
  ///
  /// `ApiClient` adds `ResilienceInterceptor.instance.forDio(dio)` to its chain, so the breakers
  /// read through [instance] are the ones real traffic updates.
  ResilienceInterceptor forDio(Dio dio) => ResilienceInterceptor._forDio(this, dio);

  // ---------------------------------------------------------------------------
  // Interceptor hooks
  // ---------------------------------------------------------------------------

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (CacheInterceptor.isCacheOnly(options) || isBypassed(options)) {
      handler.next(options);
      return;
    }

    final endpointKey = _extractEndpointKey(options.path);
    final breaker = _getBreaker(endpointKey);

    if (!breaker.allowRequest) {
      _log.warn('Circuit OPEN for endpoint "{}" — rejecting request {} {}', [
        endpointKey,
        options.method,
        options.path,
      ]);

      // Runs every onError handler, so that the dev console and the HTTP log record the request it refuses.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: CircuitBreakerOpenException(endpointKey),
          message: 'Circuit breaker is open for endpoint: $endpointKey',
        ),
        true,
      );
      return;
    }

    _log.debug('Circuit {} for endpoint "{}" — allowing request {} {}', [
      breaker.state.name,
      endpointKey,
      options.method,
      options.path,
    ]);

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (isBypassed(response.requestOptions)) {
      handler.next(response);
      return;
    }

    final endpointKey = _extractEndpointKey(response.requestOptions.path);
    final breaker = _getBreaker(endpointKey);
    breaker.recordSuccess();

    _log.debug('Success for endpoint "{}" — circuit reset to closed', [endpointKey]);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // A bypassing request is sent once and its failure is not counted: see [bypassExtraKey].
    if (isBypassed(err.requestOptions)) {
      handler.next(err);
      return;
    }

    // ConnectivityInterceptor rejected the request because the device is offline, so it was never sent: a retry would
    // only delay the cached answer, and the endpoint did not fail. The request interceptors after it never ran either,
    // so a retry would also go out without the Authorization header.
    if (err.error is ConnectivityException) {
      handler.next(err);
      return;
    }

    // A GET answered from the cache alone never reaches the network, so its failure (nothing is cached) says nothing
    // about the endpoint either.
    if (CacheInterceptor.isCacheOnly(err.requestOptions)) {
      handler.next(err);
      return;
    }

    // A TLS failure (a certificate pin mismatch, or a certificate the device does not trust) fails the handshake
    // before the request reaches the server, so it says nothing about the endpoint's health. Counted as failures, a
    // few of them would open the circuit and replace the insecure-connection error with a circuit-open one.
    if (_isTlsFailure(err)) {
      handler.next(err);
      return;
    }

    final endpointKey = _extractEndpointKey(err.requestOptions.path);
    final breaker = _getBreaker(endpointKey);

    // If this is already a circuit breaker rejection, pass through.
    if (err.error is CircuitBreakerOpenException) {
      handler.next(err);
      return;
    }

    // Studio answered with one of its error codes: that is the answer the repository must report, and it says
    // nothing about the endpoint's health, so it is neither retried nor counted.
    if (_isStudioAnswer(err)) {
      _log.debug('Passing on Studio answer {} for {} {} without retrying or counting it', [
        err.response?.statusCode,
        err.requestOptions.method,
        err.requestOptions.path,
      ]);
      handler.next(err);
      return;
    }

    // Non-retryable errors: record failure and pass through immediately.
    if (!_isRetryable(err)) {
      if (_isTransient(err)) {
        _log.debug('Not retrying {} {}: only a GET is retried', [err.requestOptions.method, err.requestOptions.path]);
      }
      // Client errors (4xx) should not trip the circuit breaker.
      if (!_isClientError(err)) {
        breaker.recordFailure();
        _log.debug('Non-retryable server error for endpoint "{}" — failure count: {}', [
          endpointKey,
          breaker.failureCount,
        ]);
      }
      handler.next(err);
      return;
    }

    // Record the failure for retryable errors.
    breaker.recordFailure();
    _log.debug('Retryable error for endpoint "{}" — failure count: {}', [endpointKey, breaker.failureCount]);

    // Attempt retry with backoff.
    _retryRequest(err, handler, endpointKey);
  }

  // ---------------------------------------------------------------------------
  // Retry logic
  // ---------------------------------------------------------------------------

  Future<void> _retryRequest(DioException err, ErrorInterceptorHandler handler, String endpointKey) async {
    final options = err.requestOptions;
    final attempt = (options.extra['_retryAttempt'] as int?) ?? 0;

    if (attempt >= maxRetries) {
      _log.warn('Max retries ({}) exhausted for {} {} — giving up', [maxRetries, options.method, options.path]);
      handler.next(err);
      return;
    }

    // Any other adapter would send the retry, Authorization header and body included, outside the
    // certificate pinning of the client's Dio, so an instance not made by forDio refuses to retry.
    final source = _dio;
    if (source == null) {
      _log.error('Cannot retry {} {}: interceptor was not made by forDio', [options.method, options.path]);
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('ResilienceInterceptor has no Dio to retry through; add instance.forDio(dio) to the chain'),
          message: 'Retry refused: no Dio to send it through',
        ),
      );
      return;
    }

    final nextAttempt = attempt + 1;
    final delay = _calculateDelay(err, nextAttempt);

    _log.info('Retry {}/{} for {} {} in {}ms', [
      nextAttempt,
      maxRetries,
      options.method,
      options.path,
      delay.inMilliseconds,
    ]);

    await Future<void>.delayed(delay);

    // Check circuit breaker again before retrying.
    final breaker = _getBreaker(endpointKey);
    if (!breaker.allowRequest) {
      _log.warn('Circuit opened during retry backoff for "{}" — aborting retry', [endpointKey]);
      // Passed on to the onError handlers after this one, as the rejection in onRequest is, so that the dev console
      // completes the entry of the request and the HTTP log records it.
      handler.next(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: CircuitBreakerOpenException(endpointKey),
          message: 'Circuit breaker opened during retry for endpoint: $endpointKey',
        ),
      );
      return;
    }

    // Clone the request with the updated retry attempt counter.
    options.extra['_retryAttempt'] = nextAttempt;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: options.baseUrl,
          connectTimeout: options.connectTimeout,
          receiveTimeout: options.receiveTimeout,
          headers: options.headers,
          responseType: options.responseType,
        ),
      );
      // Shared with the client's Dio: never close this Dio, that would close the shared adapter.
      dio.httpClientAdapter = source.httpClientAdapter;

      final response = await dio.fetch<dynamic>(options);
      breaker.recordSuccess();
      _log.info('Retry {}/{} succeeded for {} {}', [nextAttempt, maxRetries, options.method, options.path]);
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          data: response.data,
          statusCode: response.statusCode,
          statusMessage: response.statusMessage,
          headers: response.headers,
        ),
      );
    } on DioException catch (retryErr) {
      if (!_isTlsFailure(retryErr) && !_isStudioAnswer(retryErr)) breaker.recordFailure();

      if (_isRetryable(retryErr) && nextAttempt < maxRetries) {
        retryErr.requestOptions.extra['_retryAttempt'] = nextAttempt;
        _retryRequest(retryErr, handler, endpointKey);
      } else {
        _log.warn('Retry {}/{} failed for {} {} — {}', [
          nextAttempt,
          maxRetries,
          options.method,
          options.path,
          retryErr.message ?? retryErr.type.name,
        ]);
        handler.next(retryErr);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extract a stable endpoint key from a request path.
  ///
  /// Strips trailing path segments that look like IDs (numeric, UUIDs, etc.)
  /// so that `/items/123` and `/items/456` share the same breaker.
  String _extractEndpointKey(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '/';

    // Remove trailing segments that look like IDs.
    while (segments.length > 1 && _looksLikeId(segments.last)) {
      segments.removeLast();
    }

    return '/${segments.join('/')}';
  }

  /// Heuristic: a segment looks like an ID if it is purely numeric, matches
  /// a UUID-like pattern (contains dashes and hex characters), or is an email
  /// address, raw or percent-encoded (a login used as a path parameter).
  bool _looksLikeId(String segment) {
    if (RegExp(r'^\d+$').hasMatch(segment)) return true;
    if (RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(segment)) return true;
    if (emailPattern.hasMatch(segment)) return true;
    return false;
  }

  /// Get or create a circuit breaker for the given endpoint key.
  CircuitBreaker _getBreaker(String endpointKey) {
    return _breakers.putIfAbsent(
      endpointKey,
      () => CircuitBreaker(failureThreshold: failureThreshold, cooldownDuration: cooldownDuration),
    );
  }

  /// Whether an error is retryable: transient, and its request is safe to send again.
  bool _isRetryable(DioException err) => _isTransient(err) && _isSafeToRepeat(err.requestOptions);

  /// Whether an error is transient, so the same request may succeed when it is sent again.
  bool _isTransient(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.connectionError:
        return !_isClosedAfterRequestSent(err);
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode ?? 0;
        return (statusCode == 502 || statusCode == 503 || statusCode == 504) && !_isStudioAnswer(err);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      // The server already answered; a retry would only repeat the same slow response transform.
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return false;
    }
  }

  /// Whether the connection closed before a full response header arrived.
  ///
  /// dio 5.10+ reports this as a connection error (dio 5.9 reported it as unknown). The server may
  /// or may not have read and processed the request, so it is not retried. The check matches the
  /// message dio itself keys on.
  bool _isClosedAfterRequestSent(DioException err) =>
      err.error?.toString().contains('Connection closed before full header was received') ?? false;

  /// Whether [options] may be sent a second time: only a GET.
  ///
  /// One rule covers every error type. A refused connection or a connect timeout does prove that the
  /// request was never sent, but dio has moved a failure after sending into connection errors before
  /// (5.10). A POST to Studio may run a statement, and the other methods change something on the server,
  /// so none of them is repeated.
  bool _isSafeToRepeat(RequestOptions options) => options.method.toUpperCase() == 'GET';

  /// Whether [err] is an HTTP answer whose body carries a Studio error code, such as `GOVERNANCE_UNAVAILABLE`.
  bool _isStudioAnswer(DioException err) =>
      err.type == DioExceptionType.badResponse && ApiClient.errorCodeOf(err.response?.data) != null;

  /// Whether the TLS handshake failed, so the request never reached the server: see [isTlsError].
  bool _isTlsFailure(DioException err) => err.type == DioExceptionType.badCertificate || isTlsError(err.error);

  /// Whether an error is a client error (4xx) that should NOT trip the breaker.
  bool _isClientError(DioException err) {
    if (err.type != DioExceptionType.badResponse) return false;
    final statusCode = err.response?.statusCode ?? 0;
    return statusCode >= 400 && statusCode < 500;
  }

  /// Calculate the delay before the next retry attempt.
  ///
  /// Uses exponential backoff: `baseDelay * 2^(attempt-1)` plus random jitter.
  /// Respects the `Retry-After` header if present.
  Duration _calculateDelay(DioException err, int attempt) {
    // Check for Retry-After header.
    final retryAfter = err.response?.headers.value('retry-after');
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds);
      }
    }

    // Exponential backoff with jitter.
    final exponentialMs = baseDelay.inMilliseconds * pow(2, attempt - 1);
    final jitterMs = _random.nextInt(maxJitter.inMilliseconds + 1);
    return Duration(milliseconds: exponentialMs.toInt() + jitterMs);
  }
}
