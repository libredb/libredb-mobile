import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/api_target.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/auth_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_session_policy.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

/// The client of LibreDB Platform's bearer API (`/api/v1`, libredb-platform `docs/api/v1.md`), next to the Studio
/// [ApiClient] and never mixed up with it: it is its own type, so no Studio repository can be given it, and the
/// reverse.
///
/// It wraps an [ApiClient] built with Platform's target: the base URL and pins of [AppConfig.platform] and
/// [PlatformErrorEnvelope], with Platform's session rules ([isPlatformSessionExpired], [isPlatformSessionRefused]) and
/// account refusals ([platformAccountRefusal]). Its answers are never cached (every `/v1/` path and the liveness probe
/// `/health/live` are networkOnly), a coded answer is never retried, and only a GET is ever sent twice.
///
/// In a build whose [AppConfig.platform] is [PlatformNotConfigured], every call throws
/// [PlatformNotConfiguredException] and no request is sent.
final class PlatformApiClient {
  PlatformApiClient({
    required AppConfig appConfig,
    required TokenRotation tokenRotation,
    ISecureStorage? secureStorage,
    OnSessionExpired? onSessionExpired,
    OnSessionRefused? onSessionRefused,
    OnAccountRefused? onAccountRefused,
    OnTokenMissing? onTokenMissing,
    SessionExpiredPredicate isSessionExpired = isPlatformSessionExpired,
    SessionRefusedPredicate isSessionRefused = isPlatformSessionRefused,
    AccountRefusal accountRefusal = platformAccountRefusal,
    Dio? dio,
  }) : _client = switch (appConfig.platform) {
         PlatformConfigured(:final baseUrl, :final certificatePins) => ApiClient(
           appConfig: appConfig,
           secureStorage: secureStorage,
           tokenRotation: tokenRotation,
           onSessionExpired: onSessionExpired,
           onSessionRefused: onSessionRefused,
           dio: dio,
           isSessionExpired: isSessionExpired,
           isSessionRefused: isSessionRefused,
           onAccountRefused: onAccountRefused,
           accountRefusal: accountRefusal,
           onTokenMissing: onTokenMissing,
           target: ApiTarget(
             baseUrl: baseUrl,
             certificatePins: certificatePins,
             envelope: const PlatformErrorEnvelope(),
           ),
         ),
         PlatformNotConfigured() => null,
       };

  /// Null in a build without a Platform target.
  final ApiClient? _client;

  ApiClient get _configured => _client ?? (throw PlatformNotConfiguredException());

  /// The Dio of the wrapped client, for the guards and the transport tests.
  @visibleForTesting
  Dio get instance => _configured.instance;

  /// `GET` [path], relative to Platform's `/api`, with [pathParams] appended as one more path segment.
  /// [timeout] replaces the 30 seconds the client waits to connect and for the answer, and [bypassResilience] sends the
  /// request once, past an open circuit, for a probe whose failure is itself the answer, such as Platform's liveness
  /// ([ApiClient.get]).
  Future<Response<String>> get(
    String path, {
    String? pathParams,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    bool bypassResilience = false,
  }) async => _configured.get(
    path,
    pathParams: pathParams,
    queryParams: queryParams,
    timeout: timeout,
    bypassResilience: bypassResilience,
  );

  /// `PUT` [data] to [path]; never sent twice.
  Future<Response<String>> put<T>(String path, T data, {String? pathParams}) async =>
      _configured.put(path, data, pathParams: pathParams);

  /// `PATCH` [data] to [path]; never sent twice.
  Future<Response<String>> patch<T>(String path, T data, {String? pathParams}) async =>
      _configured.patch(path, data, pathParams: pathParams);

  /// `DELETE` [path]; never sent twice.
  Future<Response<String>> delete(String path, {String? pathParams, Map<String, dynamic>? queryParams}) async =>
      _configured.delete(path, pathParams: pathParams, queryParams: queryParams);
}
