import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/logging/log_sanitizer.dart';
import 'package:libredb_mobile/infrastructure/http/api_origin.dart';
import 'package:libredb_mobile/infrastructure/http/public_endpoint.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';

/// Callback signature for telling the app layer that a request was refused because no access token is stored, while
/// no sign-out or wipe of the stored session runs: the app decides whether a session it still holds as signed in ends,
/// since a session that has already ended, such as right after a sign-out, must not end again.
typedef OnTokenMissing = void Function();

/// Injects the stored access token as the Bearer token into every outgoing request, except a request
/// to a public endpoint ([isPublicEndpoint]) and a request to any origin
/// other than the API's ([isApiOriginRequest]).
///
/// Reads from [ISecureStorage] on every request. There is no in-memory
/// cache: the only data source for the JWT is the secure store, which
/// gives us a single, authoritative answer and removes the need for
/// downstream consumers (repository persist, token refresh, logout) to
/// keep a parallel cache field consistent.
///
/// It records on every request that is not to a public endpoint the
/// [SessionGeneration] the request goes out under, which
/// `TokenRefreshInterceptor` checks before it sends the request again or
/// refreshes the session for a 401.
///
/// A request that needs the session is refused before it leaves, with a
/// [NoSessionException], when the session has ended or is ending: no
/// access token is stored, or a sign-out ([SessionGeneration.signingOut],
/// except for the sign-out's own requests, [signOutRequestKey]) or a wipe
/// of the stored session is running. Sent anyway, such a request would
/// carry a token about to end or none, and its 401 would refresh or end a
/// session the user has already left (#277). The refusal skips the error
/// interceptors, so no 401 handling runs for it, and writes one warn line.
class AuthInterceptor extends Interceptor {
  static final _log = AppLogger.getLogger('AuthInterceptor');

  AuthInterceptor({ISecureStorage? secureStorage, this._onTokenMissing})
    : _secureStorage = secureStorage ?? FlutterSecureStorageAdapter();

  final ISecureStorage _secureStorage;

  /// Told when a request is refused because no access token is stored while no sign-out or wipe runs; null tells
  /// no one.
  final OnTokenMissing? _onTokenMissing;

  /// The [RequestOptions.extra] key under which [onRequest] records the [SessionGeneration] a request is sent under.
  static const sessionGenerationKey = '_sessionGeneration';

  /// The [SessionGeneration] that [onRequest] recorded for [options], or null when it recorded none: for a request to a
  /// public endpoint, or one that did not go through it.
  static int? sessionGenerationOf(RequestOptions options) => options.extra[sessionGenerationKey] as int?;

  /// The [RequestOptions.extra] key that marks a request of the sign-out itself, such as Studio's sign-out record,
  /// which still leaves while [SessionGeneration.signingOut] holds.
  static const signOutRequestKey = '_signOutRequest';

  /// Whether [options] is a request of the sign-out itself ([signOutRequestKey]).
  static bool isSignOutRequest(RequestOptions options) => options.extra[signOutRequestKey] == true;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // A public endpoint (Studio's /health and /ready, which the Studio
    // status check reads before sign-in) needs no session, so it never gets
    // the stored token. That token can be a stale one left by an expired
    // session, and a server that checks every token it receives rejects
    // such a request even where none is needed.
    if (isPublicEndpoint(options)) {
      _log.debug('Request [{}] {} (public endpoint, no token)', [options.method, options.path]);
      handler.next(options);
      return;
    }
    // Dio sends a request to an absolute URL there instead of to the base URL, so the token goes only to the origin
    // of the API, whatever path a server supplied. Such a request records no session generation either: its 401 is not
    // about the session, and TokenRefreshInterceptor passes it on. An Authorization header already on the request, set
    // by a caller or left on reused options, is removed for the same reason.
    if (!isApiOriginRequest(options)) {
      options.headers.remove('Authorization');
      _log.warn('Request [{}] to {}, another origin than the API: sent without the token', [
        options.method,
        options.uri.host,
      ]);
      handler.next(options);
      return;
    }
    if (_refuseWhileEnding(options, handler)) return;
    // Recorded before the token is read, so a 401 for this request can tell that the session it was sent under ended
    // since, even when the wipe started while the token was read.
    options.extra[sessionGenerationKey] = SessionGeneration.current;
    // ISecureStorage.read can throw on platform / decryption failure.
    // If that happens, send the request anonymously rather than failing
    // the request itself — the downstream 401 path will trigger logout
    // / re-auth, which is the right user-visible outcome. Crashing the
    // interceptor would break every HTTP call until app restart.
    String? jwtToken;
    var readFailed = false;
    try {
      jwtToken = await _secureStorage.read(SecureStorageKeys.jwtToken.key);
    } catch (e) {
      readFailed = true;
      _log.warn('secure read failed for {}; sending request without Authorization: {}', [options.path, e]);
    }
    // A sign-out or a wipe can start while the token is read.
    if (_refuseWhileEnding(options, handler)) return;
    final hasAuth = jwtToken != null && jwtToken.isNotEmpty;
    if (!hasAuth && !readFailed) {
      _refuse(options, handler, 'no access token is stored');
      _onTokenMissing?.call();
      return;
    }
    if (hasAuth) {
      options.headers['Authorization'] = 'Bearer $jwtToken';
    }
    _log.debug('Request [{}] {} (auth: {}, token: {})', [options.method, options.path, hasAuth, maskToken(jwtToken)]);
    handler.next(options);
  }

  /// Refuses [options] when a sign-out it is not part of, or a wipe of the stored session, is running; answers whether
  /// it did.
  bool _refuseWhileEnding(RequestOptions options, RequestInterceptorHandler handler) {
    if (SessionGeneration.wiping) {
      _refuse(options, handler, 'the stored session is being wiped');
      return true;
    }
    if (SessionGeneration.signingOut && !isSignOutRequest(options)) {
      _refuse(options, handler, 'a sign-out is running');
      return true;
    }
    return false;
  }

  /// Fails [options] with a [NoSessionException] for [reason] without sending it. The error interceptors are skipped:
  /// no server answered, so there is no 401 to refresh for and no session to end.
  void _refuse(RequestOptions options, RequestInterceptorHandler handler, String reason) {
    _log.warn('Request [{}] {} not sent: {}', [options.method, options.path, reason]);
    handler.reject(
      DioException(requestOptions: options, type: DioExceptionType.cancel, error: NoSessionException(reason)),
    );
  }
}
