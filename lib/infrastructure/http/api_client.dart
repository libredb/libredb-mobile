import 'dart:convert' show jsonDecode, utf8;

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/security/sensitive_data_scrubber.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinner.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinning_adapter.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/auth_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/connectivity_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/cache_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/logging_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/dev_console_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/idempotency_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/mock_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/sensitive_keys.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/http/transport_errors.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

/// Metadata describing one entry in the [ApiClient] interceptor chain.
///
/// Used by observers that want to render the chain without hard-coding
/// names/descriptions. Order matches the order in which the interceptor was added to Dio.
class InterceptorChainEntry {
  const InterceptorChainEntry({required this.name, required this.detail, this.active = true});

  final String name;
  final String detail;
  final bool active;
}

/// Dio-based HTTP client with interceptor chain.
///
/// Interceptor order (single source of truth — see the chain below):
/// 1. [ConnectivityInterceptor] — rejects requests immediately when offline
/// 2. [AuthInterceptor] — injects JWT token
/// 3. [TokenRefreshInterceptor] — handles 401 responses with token refresh
///    then [AccountRefusalInterceptor]: reports an answer that refuses the signed-in account (only with
///    `onAccountRefused`)
/// 4. [IdempotencyInterceptor] — opt-in Idempotency-Key header for mutating
///    verbs (default off; a resend after a token refresh reuses the same key)
/// 5. [ResilienceInterceptor] — retry of a GET + circuit breaker
/// 6. [CacheInterceptor] — GET response caching with TTL
/// 7. [DevConsoleInterceptor] — records requests in debug console
/// 8. [LoggingInterceptor] — structured request/response logging
/// 9. [MockInterceptor] — (dev/test only) simulates the network LAST, so its
///    response propagates back through the observability interceptors above
///    just like a real round-trip (it resolves with callFollowing:true).
///
/// Error mapping happens in the convenience methods ([get], [post], etc.)
/// which catch [DioException] and rethrow as [AppException] types so that
/// repository catch blocks work without Dio coupling.
///
/// [post], [put] and [patch] take `sensitiveKeys`, the keys of their data
/// whose values are secrets though their names hold no credential word. The
/// request carries them in its extra ([sensitiveKeysOf]), so the dev
/// console, the verbose log and the error text mask those values too.
///
/// [post] takes `receiveTimeout`, which replaces the 30 seconds the client waits for the answer of that one request,
/// for a Studio route that runs a statement (`studioStatementReceiveTimeout`).
///
/// [post] sends no header or content type of its own: every request carries the `Content-Type: application/json` of
/// the client's base options, which LibreDB Studio requires of a POST that has no `Origin` header.
///
/// `tokenRotation` is how [TokenRefreshInterceptor] refreshes the session, at the identity provider; `isSessionExpired`
/// decides which 401 starts that refresh, and `isSessionRefused` which 401 after it ends the session
/// ([isUnauthorized], every 401, when either is null).
///
/// `onAccountRefused` is told the code of every answer that `accountRefusal` reads as a refusal of the signed-in
/// account, whichever request met it; without `onAccountRefused` no request reports one.
class ApiClient {
  ApiClient({
    required this._appConfig,
    this._secureStorage,
    required this._tokenRotation,
    this._onSessionExpired,
    this._dio,
    this._isSessionExpired,
    this._isSessionRefused,
    this._onAccountRefused,
    this._accountRefusal,
  }) : assert(_onAccountRefused == null || _accountRefusal != null, 'onAccountRefused needs an accountRefusal');

  static final _log = AppLogger.getLogger('ApiClient');

  static const int _timeoutSeconds = 30;

  final AppConfig _appConfig;
  final ISecureStorage? _secureStorage;
  final OnSessionExpired? _onSessionExpired;
  final TokenRotation _tokenRotation;
  final SessionExpiredPredicate? _isSessionExpired;
  final SessionRefusedPredicate? _isSessionRefused;
  final OnAccountRefused? _onAccountRefused;
  final AccountRefusal? _accountRefusal;
  Dio? _dio;
  List<InterceptorChainEntry> _chainSnapshot = const [];

  /// Snapshot of the active interceptor chain, in order. Populated the
  /// first time [instance] is read (i.e. when Dio is built).
  ///
  /// Consumers should read this instead of hard-coding names, which keeps
  /// them in sync with the chain even when interceptors are added,
  /// removed, or conditionally included (e.g. [MockInterceptor]
  /// outside production).
  List<InterceptorChainEntry> get interceptorChainSnapshot => List.unmodifiable(_chainSnapshot);

  /// The active Dio instance.
  Dio get instance => _dio ??= _createDio();

  Dio _createDio() {
    _log.debug('Creating Dio instance (production: {})', [_appConfig.isProduction]);
    if (_secureStorage == null) {
      // Loud warning when this ApiClient was built without an injected
      // secureStorage. Production wiring (AppDependencies.createApiClient)
      // always supplies the shared adapter; if you see this in test or app
      // logs it means the interceptors are about to construct their own
      // FlutterSecureStorageAdapter instance, which will diverge from
      // whatever the repository layer / SessionCubit are using.
      _log.warn(
        'ApiClient was constructed without a secureStorage — interceptors will fall back '
        'to a private FlutterSecureStorageAdapter and diverge from the repository layer.',
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: _appConfig.apiBaseUrl ?? '',
        connectTimeout: const Duration(seconds: _timeoutSeconds),
        receiveTimeout: const Duration(seconds: _timeoutSeconds),
        responseType: ResponseType.plain,
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ),
    );

    // Certificate pinning. Empty pin list (default) keeps the system
    // adapter; populating appConfig.certificatePins swaps in a
    // pinning adapter that fails closed on any non-matching cert.
    // Retries are sent through this same adapter
    // (ResilienceInterceptor.forDio), so the pins cover every request the
    // client sends.
    final pins = _appConfig.certificatePins;
    if (pins.isNotEmpty) {
      _log.info('Installing certificate pinning adapter ({} pin(s))', [pins.length]);
      dio.httpClientAdapter = buildPinnedAdapter(pins);
    }

    // Single source of truth for the chain: each entry pairs the live
    // [Interceptor] with the human-readable metadata that observers
    // show. Adding/removing an interceptor here automatically updates
    // [interceptorChainSnapshot] — no separate hardcoded list to drift.
    final chain = <({Interceptor interceptor, InterceptorChainEntry meta})>[
      (
        interceptor: ConnectivityInterceptor(),
        meta: const InterceptorChainEntry(name: 'ConnectivityInterceptor', detail: 'Rejects requests when offline'),
      ),
      (
        interceptor: AuthInterceptor(secureStorage: _secureStorage),
        meta: const InterceptorChainEntry(name: 'AuthInterceptor', detail: 'Attaches JWT token to requests'),
      ),
      (
        interceptor: TokenRefreshInterceptor(
          dio: dio,
          onSessionExpired: _onSessionExpired,
          secureStorage: _secureStorage,
          rotation: _tokenRotation,
          isSessionExpired: _isSessionExpired ?? isUnauthorized,
          isSessionRefused: _isSessionRefused ?? isUnauthorized,
        ),
        meta: const InterceptorChainEntry(name: 'TokenRefreshInterceptor', detail: 'Refreshes expired access tokens'),
      ),
      if (_onAccountRefused case final onAccountRefused?)
        (
          interceptor: AccountRefusalInterceptor(refusalOf: _accountRefusal!, onRefused: onAccountRefused),
          meta: const InterceptorChainEntry(
            name: 'AccountRefusalInterceptor',
            detail: 'Reports an answer that refuses the signed-in account',
          ),
        ),
      (
        // Idempotency runs before Resilience so the key is set on the very
        // first outbound request and is then reused on the resend after a
        // token refresh (TokenRefresh re-fetches the same RequestOptions
        // instance, which carries the cached key in extra).
        interceptor: IdempotencyInterceptor(),
        meta: const InterceptorChainEntry(
          name: 'IdempotencyInterceptor',
          active: false,
          detail: 'Opt-in Idempotency-Key for POST/PUT/PATCH',
        ),
      ),
      (
        // Share the singleton's circuit breakers so metrics and reset
        // actions read through it see real HTTP traffic (fixes #60). forDio
        // sends retries through this Dio's adapter, pins included.
        interceptor: ResilienceInterceptor.instance.forDio(dio),
        meta: const InterceptorChainEntry(name: 'ResilienceInterceptor', detail: 'Retry + circuit breaker'),
      ),
      (
        interceptor: CacheInterceptor(),
        meta: const InterceptorChainEntry(name: 'CacheInterceptor', detail: 'GET response caching with TTL'),
      ),
      (
        interceptor: DevConsoleInterceptor(),
        meta: const InterceptorChainEntry(name: 'DevConsoleInterceptor', detail: 'Records requests in dev console'),
      ),
      (
        interceptor: LoggingInterceptor(),
        meta: const InterceptorChainEntry(name: 'LoggingInterceptor', detail: 'Structured request/response logging'),
      ),
      // Mock sits LAST: it simulates the server, so its resolved response
      // must travel back up through the observability interceptors above
      // (DevConsole capture + verbose logging). It resolves with
      // callFollowing:true to make that happen.
      if (!_appConfig.isProduction)
        (
          interceptor: MockInterceptor(appConfig: _appConfig),
          meta: const InterceptorChainEntry(
            name: 'MockInterceptor',
            active: false,
            detail: 'Serves mock data in dev/test',
          ),
        ),
    ];

    dio.interceptors.addAll(chain.map((e) => e.interceptor));
    _chainSnapshot = chain.map((e) => e.meta).toList(growable: false);

    return dio;
  }

  // ---------------------------------------------------------------------------
  // Convenience methods matching the old HttpUtils API surface
  // ---------------------------------------------------------------------------

  /// [timeout] replaces the 30 seconds the client waits to connect and for the answer of this one request.
  /// [acceptedStatuses] are statuses outside 2xx that answer this request with the response instead of an
  /// [AppException], for an endpoint whose error status carries a body the caller reads, such as Studio's 503
  /// readiness answers. Such a response is neither retried nor counted against the circuit breaker.
  /// [bypassResilience] sends the request once, past an open circuit, and leaves the circuit breaker untouched
  /// ([ResilienceInterceptor.bypassExtraKey]), for a probe whose failure is itself the answer, such as Studio's health.
  Future<Response<String>> get(
    String path, {
    String? pathParams,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    Set<int> acceptedStatuses = const {},
    bool bypassResilience = false,
  }) async {
    final fullPath = pathParams != null ? '$path/$pathParams' : path;
    try {
      return await instance.get<String>(
        fullPath,
        queryParameters: queryParams,
        options: Options(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: acceptedStatuses.isEmpty
              ? null
              : (status) => status != null && ((status >= 200 && status < 300) || acceptedStatuses.contains(status)),
          extra: {
            '_basePath': path,
            '_pathParams': pathParams,
            '_queryParams': queryParams,
            if (bypassResilience) ResilienceInterceptor.bypassExtraKey: true,
          },
        ),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<String>> post<T>(
    String path,
    T data, {
    String? pathParams,
    bool idempotent = false,
    Set<String> sensitiveKeys = const {},
    Duration? receiveTimeout,
  }) async {
    final fullPath = pathParams != null ? '$path/$pathParams' : path;
    final serialized = _serializeData(data);
    final options = Options(
      receiveTimeout: receiveTimeout,
      extra: {
        '_basePath': path,
        '_pathParams': pathParams,
        if (idempotent) IdempotencyInterceptor.optInExtraKey: true,
        if (sensitiveKeys.isNotEmpty) sensitiveKeysExtra: sensitiveKeys,
      },
    );
    try {
      return await instance.post<String>(fullPath, data: serialized, options: options);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<String>> put<T>(
    String path,
    T data, {
    String? pathParams,
    bool idempotent = false,
    Set<String> sensitiveKeys = const {},
  }) async {
    final fullPath = pathParams != null ? '$path/$pathParams' : path;
    final serialized = _serializeData(data);
    try {
      return await instance.put<String>(
        fullPath,
        data: serialized,
        options: Options(
          extra: {
            '_basePath': path,
            '_pathParams': pathParams,
            if (idempotent) IdempotencyInterceptor.optInExtraKey: true,
            if (sensitiveKeys.isNotEmpty) sensitiveKeysExtra: sensitiveKeys,
          },
        ),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<String>> patch<T>(
    String path,
    T data, {
    String? pathParams,
    bool idempotent = false,
    Set<String> sensitiveKeys = const {},
  }) async {
    final fullPath = pathParams != null ? '$path/$pathParams' : path;
    final serialized = _serializeData(data);
    try {
      return await instance.patch<String>(
        fullPath,
        data: serialized,
        options: Options(
          extra: {
            '_basePath': path,
            '_pathParams': pathParams,
            if (idempotent) IdempotencyInterceptor.optInExtraKey: true,
            if (sensitiveKeys.isNotEmpty) sensitiveKeysExtra: sensitiveKeys,
          },
        ),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<String>> delete(String path, {String? pathParams, Map<String, dynamic>? queryParams}) async {
    final fullPath = pathParams != null ? '$path/$pathParams' : path;
    try {
      return await instance.delete<String>(
        fullPath,
        queryParameters: queryParams,
        options: Options(extra: {'_basePath': path, '_pathParams': pathParams, '_queryParams': queryParams}),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping — converts DioException to AppException hierarchy
  // ---------------------------------------------------------------------------

  static AppException _mapDioException(DioException e) {
    // If the wrapped error is already an AppException (e.g. from MockInterceptor),
    // unwrap and rethrow it directly.
    if (e.error is AppException) return e.error as AppException;
    // A TLS failure gets its own type, so repositories can report AppErrorCode.networkCertInvalid instead of a
    // generic communication error: a pin mismatch, or a certificate the device does not trust. dio reports both as
    // unknown, with the exception as its error.
    if (isTlsError(e.error)) return _untrustedCertificate(e);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return FetchDataException('TimeoutException');
      case DioExceptionType.connectionError:
        // ConnectivityInterceptor refused it because the device is offline, so it never left the device.
        if (e.error is ConnectivityException) return OfflineException();
        return FetchDataException('No Internet connection');
      case DioExceptionType.badResponse:
        return _mapBadResponse(e);
      case DioExceptionType.cancel:
        return FetchDataException('Request cancelled');
      case DioExceptionType.badCertificate:
        return _untrustedCertificate(e);
      case DioExceptionType.unknown:
        return _mapUnknown(e);
    }
  }

  /// An [UntrustedCertificateException] for the TLS failure [e]. Its message is for the log, never for the user: it
  /// names the host and port and keeps what dart:io or dio reported, such as the OS error of a failed handshake.
  static UntrustedCertificateException _untrustedCertificate(DioException e) {
    final error = e.error;
    // Its message names the host and port already, so the log line of a pin mismatch stays as it was.
    if (error is CertificatePinningException) return UntrustedCertificateException(error.toString());
    final uri = e.requestOptions.uri;
    return UntrustedCertificateException('Untrusted connection to ${uri.host}:${uri.port}: ${e.message ?? error}');
  }

  static AppException _mapBadResponse(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    // The body becomes the text of the exception, which the log, the dev console and Sentry receive, and a validation
    // error can repeat the password or the code the request sent.
    final body = scrubErrorBody(
      e.response?.data,
      requestBody: e.requestOptions.data,
      sensitiveKeys: sensitiveKeysOf(e.requestOptions),
    );
    final code = errorCodeOf(e.response?.data);
    final serverMessage = _stringFieldOf(body, 'error');
    final retryAfter = _retryAfterOf(e.response?.headers);
    switch (statusCode) {
      case 400:
        return BadRequestException(body, statusCode: statusCode, errorCode: code, serverMessage: serverMessage);
      case 401 || 403:
        return UnauthorizedException(
          body,
          statusCode: statusCode,
          errorCode: code,
          serverMessage: serverMessage,
          fixStatement: _stringFieldOf(body, 'fixStatement'),
        );
      case 404:
        return FetchDataException(
          'Not found: $body',
          statusCode: statusCode,
          errorCode: code,
          serverMessage: serverMessage,
        );
      case >= 500:
        return FetchDataException(
          'Server error ($statusCode): $body',
          statusCode: statusCode,
          errorCode: code,
          retryAfter: retryAfter,
          serverMessage: serverMessage,
        );
      default:
        return FetchDataException(
          'HTTP $statusCode: $body',
          statusCode: statusCode,
          errorCode: code,
          retryAfter: retryAfter,
          serverMessage: serverMessage,
        );
    }
  }

  /// The string [field] of the scrubbed body text [scrubbedBody], when it is a JSON object.
  static String? _stringFieldOf(String scrubbedBody, String field) {
    try {
      final decoded = jsonDecode(scrubbedBody);
      return decoded is Map && decoded[field] is String ? decoded[field] as String : null;
    } on FormatException {
      return null;
    }
  }

  /// The string `code` of a JSON object body, given as a decoded map or as text. A code names a kind of failure and
  /// holds no request data, so it is read before the body is scrubbed.
  static String? errorCodeOf(Object? data) {
    Object? decoded = data;
    if (data is String) {
      try {
        decoded = jsonDecode(data);
      } on FormatException {
        return null;
      }
    }
    return decoded is Map && decoded['code'] is String ? decoded['code'] as String : null;
  }

  /// The delay of a `Retry-After` header given in seconds; the HTTP-date form is not read.
  static Duration? _retryAfterOf(Headers? headers) {
    final seconds = int.tryParse(headers?.value('retry-after')?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  static AppException _mapUnknown(DioException e) {
    final message = e.error?.toString() ?? e.message ?? 'Unknown error';
    if (message.contains('SocketException')) return FetchDataException('No Internet connection');
    if (message.contains('Timeout') || message.contains('timeout')) return FetchDataException('TimeoutException');
    return FetchDataException(message);
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  /// Decode a potentially malformed UTF-8 string.
  static String decodeUTF8(String toEncode) {
    try {
      List<int> codePoints = toEncode.runes.toList();
      List<int> utf8Bytes = utf8.encode(String.fromCharCodes(codePoints));
      return utf8.decode(utf8Bytes, allowMalformed: true);
    } catch (e) {
      return toEncode;
    }
  }

  /// Serialize [data] for Dio: Maps/Strings/Lists pass through; objects call `toJson()`.
  static dynamic _serializeData<T>(T data) {
    if (data is Map || data is String || data is List) return data;
    return (data as dynamic).toJson();
  }
}
