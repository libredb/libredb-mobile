import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/logging/log_sanitizer.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinner.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:http/http.dart' as http;
import 'package:oidc/oidc.dart';

import 'app_oidc_user_manager.dart';
import 'oidc_transaction_store.dart';

/// The platforms an `oidc` build signs in on.
enum OidcPlatformKind {
  android,
  ios;

  /// The platform this build runs on. Throws [UnsupportedError] on any other: the app ships on Android and iOS only.
  static OidcPlatformKind current() => switch (defaultTargetPlatform) {
    TargetPlatform.android => android,
    TargetPlatform.iOS => ios,
    final other => throw UnsupportedError('OIDC sign-in runs on Android and iOS only, not on ${other.name}'),
  };
}

/// The tokens of a sign-in.
final class OidcTokens {
  const OidcTokens({
    required this.accessToken,
    required this.idToken,
    required this.accessTokenExpiresAt,
    this.refreshToken,
  });

  final String accessToken;
  final String idToken;

  /// Null when the provider issued none.
  final String? refreshToken;

  /// When [accessToken] expires, in UTC, from the answer's `expires_in`.
  final DateTime accessTokenExpiresAt;

  /// Masks every token, so a log line that prints the tokens does not print a credential.
  @override
  String toString() =>
      'OidcTokens(accessToken: ${maskToken(accessToken)}, idToken: ${maskToken(idToken)}, '
      'refreshToken: ${maskToken(refreshToken)}, accessTokenExpiresAt: $accessTokenExpiresAt)';
}

/// Why a sign-in failed.
enum OidcFailure {
  /// The provider could not be reached: discovery, the JWKS or the token endpoint, or a transport failure.
  discovery,

  /// The provider answered with an error, or its answer did not pass a check.
  failed,

  /// The provider's certificate matched none of the `OIDC_CERT_PINS`: the connection may be intercepted, and the
  /// handshake failed before any request was written.
  untrustedCertificate,
}

/// How a sign-in ended.
sealed class OidcSignInOutcome {
  const OidcSignInOutcome();
}

/// The user signed in. [claims] are the claims of the verified ID token.
final class OidcSignedIn extends OidcSignInOutcome {
  const OidcSignedIn({required this.tokens, required this.claims});

  final OidcTokens tokens;
  final Map<String, Object?> claims;
}

/// The user left the provider page without signing in.
final class OidcSignInCancelled extends OidcSignInOutcome {
  const OidcSignInCancelled();
}

final class OidcSignInFailed extends OidcSignInOutcome {
  const OidcSignInFailed(this.failure);

  final OidcFailure failure;
}

/// How a provider logout ended.
sealed class OidcLogoutOutcome {
  const OidcLogoutOutcome();
}

final class ProviderSessionEnded extends OidcLogoutOutcome {
  const ProviderSessionEnded();
}

/// The provider has no logout endpoint, so only the app session ends.
final class NoProviderLogout extends OidcLogoutOutcome {
  const NoProviderLogout();
}

/// The provider logout could not be opened, the user cancelled it, or the provider answered with an error.
final class ProviderLogoutFailed extends OidcLogoutOutcome {
  const ProviderLogoutFailed();
}

/// The OpenID Connect protocol of an `oidc` build: sign-in, refresh and provider logout.
abstract interface class IOidcClient {
  /// Signs the user in through the provider's page, in a Custom Tab on Android and the shared browser session on iOS.
  Future<OidcSignInOutcome> signIn();

  /// Trades [refreshToken] for new tokens at the provider's token endpoint. The stored session's tokens are handed to
  /// the package for this one call; [idToken] may have expired.
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  });

  /// Ends the user's session at the provider, sending [idTokenHint] as `id_token_hint` when it is given.
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint});
}

/// [IOidcClient] over the oidc package's user manager.
///
/// One [AppOidcUserManager] serves the whole run. It is created on first use, and a failed `init()` drops it, so the
/// next call fetches discovery again. Each sign-in and refresh ends with the manager forgetting its user and the store
/// dropping the transaction, so the app's session storage is the only place tokens live.
///
/// The operations run one at a time, each after the previous one has ended, because they share the manager: a code
/// exchange that lands while a refresh holds the adopted user would replace that user's token, whose ID token the
/// package then reads without checking the signature, and the provider error flag would belong to two operations.
final class OidcClient implements IOidcClient {
  /// [platform] defaults to the platform the build runs on. [onManagerCreated] lets a test see each manager the client
  /// builds.
  OidcClient({
    required this._settings,
    OidcTransactionStore? store,
    http.Client? httpClient,
    OidcPlatformKind? platform,
    Future<void> Function()? cancelAndroidFlow,
    @visibleForTesting this._onManagerCreated,
  }) : _store = store ?? OidcTransactionStore(),
       _http = _ProviderHttpClient(httpClient ?? http.Client()),
       _platform = platform ?? OidcPlatformKind.current(),
       _cancelAndroidFlow = cancelAndroidFlow ?? (() => OidcAndroidHostApi().cancel());

  static final _log = AppLogger.getLogger('OidcClient');

  /// The browser of each platform: a Custom Tab on Android and the shared browser session on iOS.
  static const _platformOptions = OidcPlatformSpecificOptions(
    android: OidcNativeOptionsAndroid(useAuthTab: OidcAuthTabMode.never),
  );

  final OidcSettings _settings;
  final OidcTransactionStore _store;
  final _ProviderHttpClient _http;
  final OidcPlatformKind _platform;
  final Future<void> Function() _cancelAndroidFlow;
  final void Function(AppOidcUserManager manager)? _onManagerCreated;

  /// The run's manager once its `init()` has started, or null before that and after a failed `init()`.
  Future<AppOidcUserManager>? _ready;

  /// Completes when the last operation queued has ended, whatever its result.
  Future<void> _idle = Future<void>.value();

  /// Runs [operation] after every operation queued before it has ended. Its result and its error reach the caller
  /// unchanged; the queue only waits for it.
  Future<T> _oneAtATime<T>(Future<T> Function() operation) {
    final result = _idle.then((_) => operation());
    _idle = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<OidcSignInOutcome> signIn() => _oneAtATime(_signIn);

  Future<OidcSignInOutcome> _signIn() async {
    _http.getFailed = false;
    final AppOidcUserManager manager;
    try {
      manager = await _initializedManager();
    } on Object catch (error) {
      if (_isPinMismatch(error)) return _signInFailed(error);
      _log.warn('The identity provider could not be reached to sign in: {}', [() => _describe(error)]);
      return const OidcSignInFailed(OidcFailure.discovery);
    }
    manager.startSignIn();
    final lifecycle = _cancelOnResume();
    try {
      final user = await manager.loginAuthorizationCodeFlow(
        includeIdTokenHintFromCurrentUser: false,
        options: _platformOptions,
      );
      if (user == null) {
        if (!manager.authorizationResponseReceived) {
          _log.info('The sign-in was cancelled at the identity provider');
          return const OidcSignInCancelled();
        }
        _log.warn('The ID token of the sign-in failed a claim check');
        return const OidcSignInFailed(OidcFailure.failed);
      }
      return _signedIn(user);
    } on Object catch (error) {
      return _signInFailed(error);
    } finally {
      lifecycle?.dispose();
      await _store.clearTransactions();
      await manager.forgetUser();
    }
  }

  /// [accessTokenExpiresAt] is not handed to the package: the adopted session carries no `expires_in`, so the
  /// refreshed expiry comes only from the provider's answer, and is null when the answer has none.
  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => _oneAtATime(() => _refresh(refreshToken: refreshToken, idToken: idToken, accessToken: accessToken));

  Future<TokenRotationResult> _refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
  }) async {
    _http.getFailed = false;
    final AppOidcUserManager manager;
    try {
      manager = await _initializedManager();
    } on Object catch (error) {
      // Nothing was sent yet, so the refresh token is still good: keep the session.
      _log.warn('The identity provider could not be reached to refresh: {}', [() => _describe(error)]);
      return const RotationUnavailable();
    }
    try {
      try {
        await manager.adoptSession(idToken: idToken, accessToken: accessToken, refreshToken: refreshToken);
      } on Object catch (error) {
        _log.error('The stored ID token could not be read, so the session cannot be refreshed: {}', [
          () => _describe(error),
        ]);
        return const RotationRefused();
      }
      final user = await manager.refreshAdoptedSession();
      if (user == null) {
        _log.warn('The refreshed ID token failed a claim check');
        return const RotationRefused();
      }
      final newAccessToken = user.token.accessToken;
      if (newAccessToken == null || newAccessToken.isEmpty) {
        _log.warn('The refresh answer has no access token');
        return const RotationRefused();
      }
      var idTokenChecked = true;
      // The flag now notes only the JWKS fetch.
      _http.getFailed = false;
      try {
        await manager.verifyRefreshedIdToken(user);
      } on Object catch (error) {
        // A signature that does not verify against keys the provider served ends the session. Keys that could not be
        // fetched say nothing about the token, and the provider has already traded the refresh token, so it must not
        // be sent again: the new tokens are kept, and the unchecked ID token is dropped so the stored one stays.
        if (!_http.getFailed && !_isTransportError(error)) rethrow;
        _log.warn(
          'The keys of the identity provider could not be fetched to check the refreshed ID token, so the '
          'stored ID token is kept: {}',
          [() => _describe(error)],
        );
        idTokenChecked = false;
      }
      return TokensRotated(
        accessToken: newAccessToken,
        refreshToken: _nonEmpty(user.token.refreshToken),
        oidcIdToken: !idTokenChecked || user.token.idTokenRetainedFromPriorResponse ? null : _nonEmpty(user.idToken),
        accessTokenExpiresAt: user.token.calculateExpiresAt()?.toUtc(),
      );
    } on Object catch (error) {
      return _refreshFailed(error);
    } finally {
      await _store.clearTransactions();
      await manager.forgetUser();
    }
  }

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) =>
      _oneAtATime(() => _endProviderSession(idTokenHint: idTokenHint));

  Future<OidcLogoutOutcome> _endProviderSession({String? idTokenHint}) async {
    try {
      final manager = await _initializedManager();
      final endpoint = _logoutEndpoint(manager.discoveryDocument);
      if (endpoint == null) {
        _log.info('The identity provider has no logout endpoint, so only the app session ended');
        return const NoProviderLogout();
      }
      final OidcEndSessionResponse? response;
      final lifecycle = _cancelOnResume();
      try {
        response = await OidcFlutter.getPlatformEndSessionResponse(
          metadata: endpoint.metadata,
          request: OidcEndSessionRequest(
            clientId: _settings.clientId,
            postLogoutRedirectUri: _settings.redirectUri,
            idTokenHint: idTokenHint,
            extra: endpoint.extra,
          ),
          options: _platformOptions,
          preparationResult: OidcFlutter.prepareForRedirectFlow(_platformOptions),
        );
      } finally {
        lifecycle?.dispose();
      }
      if (response == null) {
        _log.warn('The provider logout was cancelled');
        return const ProviderLogoutFailed();
      }
      return const ProviderSessionEnded();
    } on Object catch (error) {
      _log.warn('The provider logout failed: {}', [() => _describe(error)]);
      return const ProviderLogoutFailed();
    }
  }

  /// The discovered `end_session_endpoint`; otherwise Auth0's `/v2/logout`, which takes `returnTo`, for an issuer on
  /// `auth0.com`; otherwise null.
  ({OidcProviderMetadata metadata, Map<String, dynamic>? extra})? _logoutEndpoint(OidcProviderMetadata discovered) {
    if (discovered.endSessionEndpoint != null) return (metadata: discovered, extra: null);
    final host = _settings.issuer.host;
    if (host != 'auth0.com' && !host.endsWith('.auth0.com')) return null;
    final auth0Logout = _settings.issuer.replace(path: '/v2/logout');
    return (
      metadata: OidcProviderMetadata.fromJson({...discovered.src, 'end_session_endpoint': auth0Logout.toString()}),
      extra: {'returnTo': _settings.redirectUri.toString()},
    );
  }

  Future<AppOidcUserManager> _initializedManager() => _ready ?? _initialize(_newManager());

  /// Runs [manager]'s `init()` and makes it the run's manager, or disposes and drops it when `init()` fails: the
  /// package cannot retry `init()` on the same instance.
  Future<AppOidcUserManager> _initialize(AppOidcUserManager manager) async {
    final ready = _ready = manager.init().then((_) => manager);
    try {
      return await ready;
    } on Object {
      if (identical(_ready, ready)) _ready = null;
      await manager.dispose();
      rethrow;
    }
  }

  AppOidcUserManager _newManager() {
    final manager = _buildManager();
    _onManagerCreated?.call(manager);
    return manager;
  }

  AppOidcUserManager _buildManager() => AppOidcUserManager.lazy(
    discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(_settings.issuer),
    clientCredentials: OidcClientAuthentication.none(clientId: _settings.clientId),
    store: _store,
    httpClient: _http,
    settings: OidcUserManagerSettings(
      redirectUri: _settings.redirectUri,
      postLogoutRedirectUri: _settings.redirectUri,
      scope: _settings.scopes,
      prompt: [?_settings.prompt.parameter],
      extraAuthenticationParameters: {'audience': ?_settings.audience},
      refreshBefore: null,
      // Roles come from the ID token. The package logs the whole UserInfo answer.
      userInfoSettings: const OidcUserInfoSettings(sendUserInfoRequest: false),
      revokeTokensOnLogout: false,
      supportOfflineAuth: false,
      initMode: OidcInitMode.blockingValidate,
      discoveryDocumentMaxAge: const Duration(minutes: 5),
      options: _platformOptions,
    ),
  );

  /// On Android, cancels the pending browser flow whenever the app comes back to the foreground. A closed Custom Tab
  /// tells the app nothing, so without this the flow would wait forever. After a redirect the plugin has already
  /// finished the flow, and the cancel does nothing.
  AppLifecycleListener? _cancelOnResume() {
    if (_platform != OidcPlatformKind.android) return null;
    return AppLifecycleListener(
      onResume: () => unawaited(
        _cancelAndroidFlow().catchError(
          (Object error) =>
              _log.error('The pending Android browser flow could not be cancelled: {}', [() => _describe(error)]),
        ),
      ),
    );
  }

  OidcSignInOutcome _signedIn(OidcUser user) {
    final accessToken = user.token.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      _log.warn('The token answer of the sign-in has no access token');
      return const OidcSignInFailed(OidcFailure.failed);
    }
    if (user.idToken.isEmpty) {
      _log.warn('The token answer of the sign-in has no ID token');
      return const OidcSignInFailed(OidcFailure.failed);
    }
    final expiresAt = user.token.calculateExpiresAt();
    if (expiresAt == null) {
      _log.warn('The token answer of the sign-in has no expires_in, so the session would never be refreshed');
      return const OidcSignInFailed(OidcFailure.failed);
    }
    return OidcSignedIn(
      tokens: OidcTokens(
        accessToken: accessToken,
        idToken: user.idToken,
        refreshToken: _nonEmpty(user.token.refreshToken),
        accessTokenExpiresAt: expiresAt.toUtc(),
      ),
      claims: Map.of(user.claims.toJson())..removeWhere((name, _) => _protocolClaims.contains(name)),
    );
  }

  /// ID token claims that only bind the token to this sign-in. The `nonce` must never reach a log line, and a caller
  /// needs none of them.
  static const _protocolClaims = {'nonce', 'at_hash', 'c_hash'};

  /// A certificate that matches no pin is [OidcFailure.untrustedCertificate]; a transport failure, or a discovery or
  /// JWKS failure, is [OidcFailure.discovery]; an error answer or a failed check, such as a bad signature or a nonce
  /// mismatch, is [OidcFailure.failed].
  OidcSignInOutcome _signInFailed(Object error) {
    final failure = _isPinMismatch(error)
        ? OidcFailure.untrustedCertificate
        : _http.getFailed || _isTransportError(error)
        ? OidcFailure.discovery
        : OidcFailure.failed;
    _log.warn('The sign-in failed ({}): {}', [failure.name, () => _describe(error)]);
    return OidcSignInFailed(failure);
  }

  /// The provider refusing, or a refreshed ID token failing a check, ends the session; the provider being out of
  /// reach keeps it. A GET error status comes first, and so does a token endpoint status of 429 or 5xx, whatever its
  /// error code. The JWKS of a refreshed ID token is handled before this, since its grant has already been answered.
  TokenRotationResult _refreshFailed(Object error) {
    final TokenRotationResult result;
    final status = error is OidcException ? error.rawResponse?.statusCode : null;
    if (_http.getFailed) {
      result = const RotationUnavailable();
    } else if (status != null && (status == 429 || status >= 500)) {
      // Too many requests, or the provider failing, says nothing about the refresh token, whatever the error code.
      result = const RotationUnavailable();
    } else if (error is JoseException) {
      result = const RotationRefused();
    } else {
      result = switch (OidcOfflineAuthErrorHandler.categorizeError(error)) {
        OfflineAuthErrorType.networkUnavailable ||
        OfflineAuthErrorType.networkTimeout ||
        OfflineAuthErrorType.sslError ||
        OfflineAuthErrorType.serverError => const RotationUnavailable(),
        OfflineAuthErrorType.authenticationError || OfflineAuthErrorType.clientError => const RotationRefused(),
        OfflineAuthErrorType.unknown =>
          _isTransportError(error) ? const RotationUnavailable() : const RotationRefused(),
      };
    }
    _log.warn('The refresh failed ({}): {}', [result.runtimeType, () => _describe(error)]);
    return result;
  }

  /// Whether [error], or the error an [OidcException] wraps, is a certificate that matched no pin.
  static bool _isPinMismatch(Object error) => _cause(error) is CertificatePinningException;

  static Object _cause(Object error) => error is OidcException ? error.internalException ?? error : error;

  /// Whether [error], or the error an [OidcException] wraps, is a transport failure: no network, a timeout or TLS,
  /// a certificate that matched no pin included, since its handshake failed before any request was written.
  static bool _isTransportError(Object error) {
    final cause = _cause(error);
    if (cause is CertificatePinningException) return true;
    return switch (OidcOfflineAuthErrorHandler.categorizeError(cause)) {
      OfflineAuthErrorType.networkUnavailable ||
      OfflineAuthErrorType.networkTimeout ||
      OfflineAuthErrorType.sslError => true,
      _ => false,
    };
  }

  /// The type of [error] and, for an [OidcException], the provider's error code and status. Never its message, its
  /// request or its response, which can carry a token, the code, the verifier or a URL with `state`.
  static String _describe(Object error) => switch (error) {
    OidcException(:final errorResponse, :final rawResponse, :final internalException) =>
      'OidcException(error: ${errorResponse?.error}, status: ${rawResponse?.statusCode}, '
          'cause: ${internalException?.runtimeType})',
    _ => '${error.runtimeType}',
  };

  static String? _nonEmpty(String? value) => value == null || value.isEmpty ? null : value;
}

/// Passes the requests to the provider on, and notes a GET the provider answers with an error status. Discovery runs
/// inside the manager's `init()`, so during a sign-in or a refresh the only GET is the JWKS, whose failure the
/// package does not report as such: jose_plus parses the error page as a key set.
final class _ProviderHttpClient extends http.BaseClient {
  _ProviderHttpClient(this._inner);

  final http.Client _inner;

  /// Whether a GET answered with a status of 400 or more since the flag was last cleared.
  bool getFailed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (request.method == 'GET' && response.statusCode >= 400) getFailed = true;
    return response;
  }
}
