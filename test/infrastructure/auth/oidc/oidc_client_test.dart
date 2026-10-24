import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/app_oidc_user_manager.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_transaction_store.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinner.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinning_adapter.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:oidc/oidc.dart';

import '../../../support/loopback_tls_server.dart';
import '../../../support/printed_lines.dart';
import '../../../support/pin_test_certificates.dart';
import 'support/fake_provider.dart';

void main() {
  late FakeProvider provider;
  late FakeOidcPlatform platform;
  late OidcTransactionStore store;

  setUp(() {
    provider = FakeProvider();
    platform = installFakePlatform(provider);
    store = OidcTransactionStore();
  });

  OidcSettings settingsFor(FakeProvider provider, {String? audience, OidcPrompt prompt = OidcPrompt.login}) =>
      OidcSettings(issuer: Uri.parse(provider.issuer), clientId: fakeClientId, audience: audience, prompt: prompt);

  OidcClient newClient({
    OidcSettings? settings,
    OidcPlatformKind platformKind = OidcPlatformKind.ios,
    OidcTransactionStore? transactionStore,
    FakeProvider? at,
    Future<void> Function()? cancelAndroidFlow,
    void Function(AppOidcUserManager manager)? onManagerCreated,
  }) {
    final idp = at ?? provider;
    return OidcClient(
      settings: settings ?? settingsFor(idp),
      store: transactionStore ?? store,
      httpClient: idp.client,
      platform: platformKind,
      cancelAndroidFlow: cancelAndroidFlow ?? () async => fail('cancelAndroidFlow was not expected'),
      onManagerCreated: onManagerCreated,
    );
  }

  Future<OidcSignInOutcome> signIn(OidcClient client) => client.signIn();

  Future<void> expectStoreEmpty() async {
    expect(await store.getAllKeys(OidcStoreNamespace.state), isEmpty, reason: 'states left in the store');
    expect(await store.getAllKeys(OidcStoreNamespace.stateResponse), isEmpty, reason: 'responses left in the store');
    expect(await store.getAllKeys(OidcStoreNamespace.secureTokens), isEmpty, reason: 'secure keys left in the store');
  }

  group('signIn', () {
    test('success gives OidcSignedIn with the tokens, the claims and an expiry of now + expires_in', () async {
      provider.expiresIn = 120;
      final before = clock.now().toUtc();

      final outcome = await signIn(newClient());

      final after = clock.now().toUtc();
      expect(outcome, isA<OidcSignedIn>());
      final signedIn = outcome as OidcSignedIn;
      expect(signedIn.tokens.accessToken, 'access-1-value');
      expect(signedIn.tokens.refreshToken, 'refresh-1-value');
      expect(signedIn.tokens.idToken, isNotEmpty);
      expect(signedIn.claims['sub'], fakeSubject);
      expect(signedIn.claims['realm_access'], {
        'roles': ['admin'],
      });
      final expiresAt = signedIn.tokens.accessTokenExpiresAt;
      expect(expiresAt.isUtc, isTrue);
      expect(expiresAt.isBefore(before.add(const Duration(seconds: 120))), isFalse);
      expect(expiresAt.isAfter(after.add(const Duration(seconds: 120))), isFalse);
      await expectStoreEmpty();
    });

    test('OidcTokens masks every token in toString', () async {
      final outcome = await signIn(newClient()) as OidcSignedIn;

      final text = outcome.tokens.toString();
      expect(text, isNot(contains(outcome.tokens.accessToken)));
      expect(text, isNot(contains(outcome.tokens.idToken)));
      expect(text, isNot(contains(outcome.tokens.refreshToken!)));
    });

    test('the platform answering null is OidcSignInCancelled', () async {
      platform.authorization = FakeAuthorization.cancel;

      expect(await signIn(newClient()), isA<OidcSignInCancelled>());
      expect(provider.tokenRequests, isEmpty);
      await expectStoreEmpty();
    });

    test('an ID token with a wrong aud is failed', () async {
      provider.audience = 'someone-else';

      expect(await signIn(newClient()), _failed(OidcFailure.failed));
      await expectStoreEmpty();
    });

    test('an ID token with another nonce is failed', () async {
      provider.codeAnswer = () => provider.tokenAnswer(nonce: 'another-nonce');

      expect(await signIn(newClient()), _failed(OidcFailure.failed));
      expect(provider.tokenRequests, hasLength(1));
      await expectStoreEmpty();
    });

    test('the claims leave out the nonce, at_hash and c_hash of the ID token', () async {
      provider.hashClaims = true;

      final outcome = await signIn(newClient());

      expect(outcome, isA<OidcSignedIn>());
      final signedIn = outcome as OidcSignedIn;
      final idTokenClaims = JsonWebToken.unverified(signedIn.tokens.idToken).claims.toJson();
      expect(idTokenClaims.keys, containsAll(<String>['nonce', 'at_hash', 'c_hash']));
      expect(signedIn.claims.keys, isNot(anyOf(contains('nonce'), contains('at_hash'), contains('c_hash'))));
      expect(signedIn.claims['sub'], fakeSubject);
      expect(signedIn.claims['preferred_username'], 'person');
      expect(signedIn.claims.toString(), isNot(contains(idTokenClaims['nonce'] as String)));
    });

    test('an ID token with a bad signature is failed', () async {
      provider.signWithForeignKey = true;

      expect(await signIn(newClient()), _failed(OidcFailure.failed));
      await expectStoreEmpty();
    });

    test('discovery answering 500 is discovery', () async {
      provider.discoveryAnswer = () => http.Response('<html>down</html>', 500);

      expect(await signIn(newClient()), _failed(OidcFailure.discovery));
      expect(platform.authorizeRequests, isEmpty);
    });

    test('discovery unreachable is discovery', () async {
      provider.discoveryAnswer = () => throw http.ClientException('connection refused');

      expect(await signIn(newClient()), _failed(OidcFailure.discovery));
    });

    test('a failed discovery is fetched again by the next sign-in', () async {
      provider.discoveryAnswer = () => throw http.ClientException('connection refused');
      final client = newClient();
      expect(await signIn(client), _failed(OidcFailure.discovery));

      provider.discoveryAnswer = null;

      expect(await signIn(client), isA<OidcSignedIn>());
    });

    test('a manager whose discovery failed is disposed', () async {
      provider.discoveryAnswer = () => throw http.ClientException('connection refused');
      final managers = <AppOidcUserManager>[];

      expect(await signIn(newClient(onManagerCreated: managers.add)), _failed(OidcFailure.discovery));

      expect(managers.single.isDisposed, isTrue, reason: 'the failed manager was left running');
    });

    test('discovery naming another issuer is discovery', () async {
      provider.discoveryIssuer = 'https://evil.test/realms/demo';

      expect(await signIn(newClient()), _failed(OidcFailure.discovery));
      expect(platform.authorizeRequests, isEmpty);
    });

    test('the JWKS answering 500 is discovery', () async {
      provider.jwksAnswer = () => http.Response('<html>down</html>', 500);

      expect(await signIn(newClient()), _failed(OidcFailure.discovery));
      await expectStoreEmpty();
    });

    test('the JWKS unreachable is discovery', () async {
      provider.jwksAnswer = () => throw http.ClientException('connection reset');

      expect(await signIn(newClient()), _failed(OidcFailure.discovery));
    });

    test('the token endpoint unreachable is discovery', () async {
      provider.codeAnswer = () => throw http.ClientException('connection reset');

      expect(await signIn(newClient()), _failed(OidcFailure.discovery));
      await expectStoreEmpty();
    });

    group('a provider certificate that matches no pin', () {
      const mismatch = CertificatePinningException('id.example.test', 443);

      /// The client the app builds for OIDC_CERT_PINS, for an issuer on [server]. It must be built inside
      /// withRealSockets, since an HttpClient takes its overrides when it is created.
      OidcClient pinnedClient(HttpServer server, List<String> pins) => OidcClient(
        settings: OidcSettings(issuer: Uri.parse('https://127.0.0.1:${server.port}/realms/demo'), clientId: 'app'),
        store: store,
        httpClient: pinnedHttpClient(pins),
        platform: OidcPlatformKind.ios,
      );

      test('at discovery is untrustedCertificate, opens no browser and sends no token request', () async {
        provider.discoveryAnswer = () => throw mismatch;

        expect(await signIn(newClient()), _failed(OidcFailure.untrustedCertificate));
        expect(platform.authorizeRequests, isEmpty);
        expect(provider.tokenRequests, isEmpty);
        await expectStoreEmpty();
      });

      test('at the token endpoint is untrustedCertificate and keeps nothing', () async {
        provider.codeAnswer = () => throw mismatch;

        expect(await signIn(newClient()), _failed(OidcFailure.untrustedCertificate));
        await expectStoreEmpty();
      });

      test('at the JWKS is untrustedCertificate and keeps nothing', () async {
        provider.jwksAnswer = () => throw mismatch;

        expect(await signIn(newClient()), _failed(OidcFailure.untrustedCertificate));
        await expectStoreEmpty();
      });

      // The client the app builds for OIDC_CERT_PINS, over a real TLS handshake with an issuer whose key is not
      // pinned: the handshake fails before any request is written.
      test('over a real handshake through the pinned client is untrustedCertificate', () async {
        var requests = 0;
        final server = await startLoopbackTlsServer(onRequest: (_) => requests++);

        final outcome = await withRealSockets(
          () => pinnedClient(server, [rsaCertificatePin, ecCertificatePin]).signIn(),
        );

        expect(outcome, _failed(OidcFailure.untrustedCertificate));
        expect(requests, 0, reason: 'a request reached the server whose key is not pinned');
        expect(platform.authorizeRequests, isEmpty);
        await expectStoreEmpty();
      });

      test('over a real handshake through the pinned client passes the pin check when the key matches', () async {
        var requests = 0;
        final server = await startLoopbackTlsServer(onRequest: (_) => requests++);
        final pins = [CertificatePinner.computePin(loopbackCertificateDer), rsaCertificatePin];

        final outcome = await withRealSockets(() => pinnedClient(server, pins).signIn());

        // The loopback server answers `ok` to discovery, so the pin passed and discovery failed after it.
        expect(outcome, _failed(OidcFailure.discovery));
        expect(requests, 1, reason: 'discovery did not reach the server whose key is pinned');
      });
    });

    test('an error=access_denied redirect is failed', () async {
      platform.authorization = FakeAuthorization.accessDenied;

      expect(await signIn(newClient()), _failed(OidcFailure.failed));
      expect(provider.tokenRequests, isEmpty);
      await expectStoreEmpty();
    });

    test('a token endpoint invalid_grant is failed', () async {
      provider.codeAnswer = () => FakeProvider.errorAnswer('invalid_grant');

      expect(await signIn(newClient()), _failed(OidcFailure.failed));
      await expectStoreEmpty();
    });

    test('a token answer without an ID token is failed', () async {
      provider.codeAnswer = () => provider.tokenAnswer(idToken: false);

      expect(await signIn(newClient()), _failed(OidcFailure.failed));
    });

    test('a token answer with an empty access token is failed', () async {
      provider.codeAnswer = () => provider.tokenAnswer(nonce: provider.nonce, accessToken: '');

      expect(await signIn(newClient()), _failed(OidcFailure.failed));
    });

    test('a token answer without expires_in is failed', () async {
      provider.expiresIn = null;

      expect(await signIn(newClient()), _failed(OidcFailure.failed));
      await expectStoreEmpty();
    });

    test('the authorization URL carries prompt=login, S256 PKCE, a nonce and the audience', () async {
      await signIn(newClient(settings: settingsFor(provider, audience: 'https://api.example.test')));

      final query = platform.lastAuthorizeUri.queryParameters;
      expect(query['prompt'], 'login');
      expect(query['code_challenge_method'], 'S256');
      expect(query['code_challenge'], isNotEmpty);
      expect(query['nonce'], isNotEmpty);
      expect(query['audience'], 'https://api.example.test');
      expect(query['client_id'], fakeClientId);
      expect(query['redirect_uri'], 'org.libredb.mobile:/oauth2redirect');
      expect(query, isNot(contains('id_token_hint')));
    });

    test('the authorization URL carries no prompt for omit and no audience when unset', () async {
      await signIn(newClient(settings: settingsFor(provider, prompt: OidcPrompt.omit)));

      final query = platform.lastAuthorizeUri.queryParameters;
      expect(query, isNot(contains('prompt')));
      expect(query, isNot(contains('audience')));
    });

    test('no request ever carries client_secret', () async {
      final client = newClient();
      final signedIn = await signIn(client) as OidcSignedIn;
      await client.refresh(
        refreshToken: signedIn.tokens.refreshToken!,
        idToken: signedIn.tokens.idToken,
        accessToken: signedIn.tokens.accessToken,
        accessTokenExpiresAt: signedIn.tokens.accessTokenExpiresAt,
      );

      expect(provider.tokenRequests, hasLength(2));
      for (final request in provider.requests) {
        expect(request.url.queryParameters, isNot(contains('client_secret')));
        expect(request.body, isNot(contains('client_secret')));
        expect(request.headers.keys.map((key) => key.toLowerCase()), isNot(contains('authorization')));
      }
      expect(platform.lastAuthorizeUri.queryParameters, isNot(contains('client_secret')));
    });

    test('the code exchange sends the PKCE verifier and a public client id', () async {
      await signIn(newClient());

      final form = FakeProvider.form(provider.tokenRequests.single);
      expect(form['grant_type'], 'authorization_code');
      expect(form['client_id'], fakeClientId);
      expect(form['code_verifier'], isNotEmpty);
    });

    test('the platform options keep the Custom Tab and the shared Apple session', () async {
      await signIn(newClient());

      final options = platform.authorizeOptions.single;
      expect(options.android.useAuthTab, OidcAuthTabMode.never);
      expect(options.ios.prefersEphemeralWebBrowserSession, isFalse);
    });

    test('the redirect URI is the custom scheme of the app', () async {
      await signIn(newClient());

      expect(platform.lastAuthorizeUri.queryParameters['redirect_uri'], 'org.libredb.mobile:/oauth2redirect');
    });
  });

  group('Android', () {
    testWidgets('resuming the app while a sign-in is pending cancels it', (tester) async {
      platform.authorization = FakeAuthorization.pending;
      var cancels = 0;
      final client = newClient(
        platformKind: OidcPlatformKind.android,
        cancelAndroidFlow: () async {
          cancels++;
          platform.completePending();
        },
      );

      final outcome = await tester.runAsync(() async {
        final result = signIn(client);
        while (!platform.hasPending) {
          await Future<void>.delayed(Duration.zero);
        }
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        return result;
      });

      expect(outcome, isA<OidcSignInCancelled>());
      expect(cancels, 1);
      await tester.runAsync(expectStoreEmpty);
    });

    testWidgets('resuming the app after the sign-in ended cancels nothing', (tester) async {
      var cancels = 0;
      final client = newClient(platformKind: OidcPlatformKind.android, cancelAndroidFlow: () async => cancels++);

      final outcome = await tester.runAsync(() => signIn(client));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(outcome, isA<OidcSignedIn>());
      expect(cancels, 0);
    });

    testWidgets('resuming the app while a provider logout is pending cancels it', (tester) async {
      platform.endSession = FakeEndSession.pending;
      final client = newClient(
        platformKind: OidcPlatformKind.android,
        cancelAndroidFlow: () async {
          platform.completePending();
        },
      );

      final outcome = await tester.runAsync(() async {
        final result = client.endProviderSession(idTokenHint: 'id-token-value');
        while (!platform.hasPending) {
          await Future<void>.delayed(Duration.zero);
        }
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        return result;
      });

      expect(outcome, isA<ProviderLogoutFailed>());
    });
  });

  group('refresh', () {
    Future<TokenRotationResult> refresh(OidcClient client, {String? idToken}) => client.refresh(
      refreshToken: 'refresh-old-value',
      idToken: idToken ?? provider.signIdToken(),
      accessToken: 'access-old-value',
      accessTokenExpiresAt: clock.now().toUtc().subtract(const Duration(seconds: 5)),
    );

    test('a new ID token gives TokensRotated with a new expiry and oidcIdToken', () async {
      provider.expiresIn = 60;
      final before = clock.now().toUtc();

      final result = await refresh(newClient());

      expect(result, isA<TokensRotated>());
      final rotated = result as TokensRotated;
      expect(rotated.accessToken, 'access-1-value');
      expect(rotated.refreshToken, 'refresh-1-value');
      expect(rotated.oidcIdToken, isNotEmpty);
      expect(rotated.accessTokenExpiresAt!.isBefore(before.add(const Duration(seconds: 60))), isFalse);
      final form = FakeProvider.form(provider.tokenRequests.single);
      expect(form['grant_type'], 'refresh_token');
      expect(form['refresh_token'], 'refresh-old-value');
      expect(form['client_id'], fakeClientId);
      await expectStoreEmpty();
    });

    test('an answer without an ID token keeps the old one', () async {
      provider.refreshReturnsIdToken = false;

      final result = await refresh(newClient());

      expect(result, isA<TokensRotated>());
      expect((result as TokensRotated).oidcIdToken, isNull);
      expect(result.accessToken, 'access-1-value');
    });

    test('an already expired stored ID token still refreshes', () async {
      provider.refreshReturnsIdToken = false;
      final expired = provider.signIdToken(ttl: const Duration(minutes: -10));

      final result = await refresh(newClient(), idToken: expired);

      expect(result, isA<TokensRotated>());
      expect(provider.tokenRequests, hasLength(1));
    });

    test('an already expired stored ID token refreshes to a new one', () async {
      final expired = provider.signIdToken(ttl: const Duration(minutes: -10));

      final result = await refresh(newClient(), idToken: expired);

      expect(result, isA<TokensRotated>());
      expect((result as TokensRotated).oidcIdToken, isNot(expired));
    });

    test('an answer without expires_in gives no expiry', () async {
      provider.expiresIn = null;

      final result = await refresh(newClient());

      expect(result, isA<TokensRotated>());
      expect((result as TokensRotated).accessTokenExpiresAt, isNull);
    });

    test('an answer with an empty access token is RotationRefused', () async {
      provider.refreshAnswer = () => provider.tokenAnswer(accessToken: '');

      expect(await refresh(newClient()), isA<RotationRefused>());
    });

    test('invalid_grant is RotationRefused', () async {
      provider.refreshAnswer = () => FakeProvider.errorAnswer('invalid_grant');

      expect(await refresh(newClient()), isA<RotationRefused>());
      await expectStoreEmpty();
    });

    test('invalid_client is RotationRefused', () async {
      provider.refreshAnswer = () => FakeProvider.errorAnswer('invalid_client', status: 401);

      expect(await refresh(newClient()), isA<RotationRefused>());
    });

    test('a transport error is RotationUnavailable', () async {
      provider.refreshAnswer = () => throw http.ClientException('connection reset');

      expect(await refresh(newClient()), isA<RotationUnavailable>());
      await expectStoreEmpty();
    });

    for (final error in ['server_error', 'temporarily_unavailable']) {
      test('$error is RotationUnavailable', () async {
        provider.refreshAnswer = () => FakeProvider.errorAnswer(error, status: 503);

        expect(await refresh(newClient()), isA<RotationUnavailable>());
      });
    }

    test('a 502 with an HTML body is RotationUnavailable', () async {
      provider.refreshAnswer = () => http.Response('<html>Bad gateway</html>', 502);

      expect(await refresh(newClient()), isA<RotationUnavailable>());
    });

    test('a 400 with a body that is not JSON is RotationRefused', () async {
      provider.refreshAnswer = () => http.Response('bad request', 400);

      expect(await refresh(newClient()), isA<RotationRefused>());
    });

    test('a refreshed ID token with a wrong aud is RotationRefused', () async {
      final stored = provider.signIdToken();
      provider.audience = 'someone-else';

      expect(await refresh(newClient(), idToken: stored), isA<RotationRefused>());
    });

    test('a refreshed ID token with a bad signature is RotationRefused', () async {
      final stored = provider.signIdToken();
      provider.signWithForeignKey = true;

      expect(await refresh(newClient(), idToken: stored), isA<RotationRefused>());
    });

    test('a stored ID token that does not parse is RotationRefused, with no request', () async {
      expect(await refresh(newClient(), idToken: 'not-a-jwt'), isA<RotationRefused>());
      expect(provider.tokenRequests, isEmpty);
    });

    // The token endpoint has already answered, so the old refresh token is spent: the new tokens are kept, and the
    // new ID token, which could not be checked, is left out so the stored one stays.
    void expectRotatedWithoutIdToken(TokenRotationResult result) {
      expect(result, isA<TokensRotated>());
      final rotated = result as TokensRotated;
      expect(rotated.accessToken, 'access-1-value');
      expect(rotated.refreshToken, 'refresh-1-value');
      expect(rotated.oidcIdToken, isNull);
      expect(rotated.accessTokenExpiresAt, isNotNull);
      expect(provider.tokenRequests, hasLength(1));
    }

    test(
      'the JWKS answering 500 with an HTML body during a refresh keeps the new tokens and the old ID token',
      () async {
        provider.jwksAnswer = () => http.Response('<html>down</html>', 500);

        expectRotatedWithoutIdToken(await refresh(newClient()));
        await expectStoreEmpty();
      },
    );

    test(
      'the JWKS answering 503 with a JSON body during a refresh keeps the new tokens and the old ID token',
      () async {
        provider.jwksAnswer = () =>
            http.Response('{"error":"temporarily_unavailable"}', 503, headers: {'content-type': 'application/json'});

        expectRotatedWithoutIdToken(await refresh(newClient()));
        await expectStoreEmpty();
      },
    );

    test('the JWKS unreachable during a refresh keeps the new tokens and the old ID token', () async {
      provider.jwksAnswer = () => throw http.ClientException('connection reset');

      expectRotatedWithoutIdToken(await refresh(newClient()));
      await expectStoreEmpty();
    });

    test('a token endpoint 429 is RotationUnavailable, whatever its error code', () async {
      provider.refreshAnswer = () => FakeProvider.errorAnswer('invalid_request', status: 429);

      expect(await refresh(newClient()), isA<RotationUnavailable>());
    });

    test('a token endpoint 500 with an unknown error code is RotationUnavailable', () async {
      provider.refreshAnswer = () => FakeProvider.errorAnswer('database_on_fire', status: 500);

      expect(await refresh(newClient()), isA<RotationUnavailable>());
    });

    // The handshake failed before the refresh token was written, so the session is kept.
    test('a token endpoint certificate that matches no pin is RotationUnavailable', () async {
      provider.refreshAnswer = () => throw const CertificatePinningException('id.example.test', 443);

      expect(await refresh(newClient()), isA<RotationUnavailable>());
      await expectStoreEmpty();
    });

    test('discovery unreachable during a refresh gives RotationUnavailable', () async {
      provider.discoveryAnswer = () => throw http.ClientException('connection refused');

      expect(await refresh(newClient()), isA<RotationUnavailable>());
      expect(provider.tokenRequests, isEmpty);
    });

    test('discovery 500 during a refresh gives RotationUnavailable', () async {
      provider.discoveryAnswer = () => http.Response('<html>down</html>', 500);

      expect(await refresh(newClient()), isA<RotationUnavailable>());
      expect(provider.tokenRequests, isEmpty);
    });

    test('an expired session is refreshed with exactly one token request', () async {
      final result = await refresh(newClient());

      expect(result, isA<TokensRotated>());
      expect(provider.tokenRequests, hasLength(1), reason: 'a package timer refreshed the adopted session as well');
    });

    test('a sign-in after a refresh sends no id_token_hint', () async {
      final client = newClient();
      await refresh(client);

      await signIn(client);

      expect(platform.lastAuthorizeUri.queryParameters, isNot(contains('id_token_hint')));
    });
  });

  test(
    'no background refresh: an access token that has expired at the sign-in is not refreshed by the package',
    () async {
      // Real time, not fake time: jose_plus verifies the ID token signature on a path that never completes under
      // fake_async, so a sign-in in fake time never ends and a test that advances the clock past expires_in cannot
      // run. A token that has expired when it arrives makes the package's expired timer fire at once instead, which
      // the client forgetting its user after the sign-in cannot hide.
      // The package's expired timer fires at once for such a token and refreshes it, unless the manager arms no timer.
      provider.expiresIn = 0;
      // A refused refresh ends the package's refresh loop, which would otherwise never stop for a 0 second token.
      provider.refreshAnswer = () => FakeProvider.errorAnswer('invalid_grant');

      expect(await newClient().signIn(), isA<OidcSignedIn>());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(provider.tokenRequests, hasLength(1), reason: 'a package timer refreshed the token during the sign-in');
    },
  );

  group('OidcPlatformKind.current', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('maps Android and iOS to their kind', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(OidcPlatformKind.current(), OidcPlatformKind.android);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(OidcPlatformKind.current(), OidcPlatformKind.ios);
    });

    test('refuses every other platform', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(OidcPlatformKind.current, throwsUnsupportedError, reason: platform.name);
      }
    });
  });

  group('one operation at a time', () {
    test('an operation that throws does not stop the next one', () async {
      final breaking = _ClearFailsOnceStore();
      final client = newClient(transactionStore: breaking);

      await expectLater(client.signIn(), throwsStateError);

      expect(await client.signIn(), isA<OidcSignedIn>());
      expect(await client.endProviderSession(idTokenHint: 'id-token-value'), isA<ProviderSessionEnded>());
    });

    test('a sign-in started during a refresh runs after it, and its ID token signature is still checked', () async {
      final refreshAnswer = Completer<http.Response>();
      provider.refreshAnswer = () => refreshAnswer.future;
      final client = newClient();
      final refreshing = client.refresh(
        refreshToken: 'refresh-old-value',
        idToken: provider.signIdToken(),
        accessToken: 'access-old-value',
        accessTokenExpiresAt: clock.now().toUtc(),
      );
      while (provider.tokenRequests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      provider.signWithForeignKey = true;

      final signingIn = signIn(client);
      for (var turn = 0; turn < 20; turn++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(platform.authorizeRequests, isEmpty, reason: 'the sign-in started while the refresh was in flight');
      refreshAnswer.complete(provider.tokenAnswer(idToken: false));
      expect(await refreshing, isA<TokensRotated>());
      expect(await signingIn, _failed(OidcFailure.failed));
      expect(platform.authorizeRequests, hasLength(1));
      await expectStoreEmpty();
    });

    test('a refresh started during a sign-in runs after it', () async {
      platform.authorization = FakeAuthorization.pending;
      final client = newClient();
      final signingIn = signIn(client);
      while (!platform.hasPending) {
        await Future<void>.delayed(Duration.zero);
      }

      final refreshing = client.refresh(
        refreshToken: 'refresh-old-value',
        idToken: provider.signIdToken(),
        accessToken: 'access-old-value',
        accessTokenExpiresAt: clock.now().toUtc(),
      );
      for (var turn = 0; turn < 20; turn++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(provider.tokenRequests, isEmpty, reason: 'the refresh started while the sign-in was pending');
      platform.completePending();
      expect(await signingIn, isA<OidcSignInCancelled>());
      expect(await refreshing, isA<TokensRotated>());
    });
  });

  group('endProviderSession', () {
    test('with a hint, the end-session URL carries client_id, post_logout_redirect_uri and id_token_hint', () async {
      final outcome = await newClient().endProviderSession(idTokenHint: 'id-token-value');

      expect(outcome, isA<ProviderSessionEnded>());
      final uri = platform.lastEndSessionUri;
      expect(uri.replace(query: ''), provider.logoutUri.replace(query: ''));
      expect(uri.queryParameters, {
        'client_id': fakeClientId,
        'post_logout_redirect_uri': 'org.libredb.mobile:/oauth2redirect',
        'id_token_hint': 'id-token-value',
      });
    });

    test('the provider logout keeps the Custom Tab and the shared Apple session', () async {
      await newClient().endProviderSession(idTokenHint: 'id-token-value');

      final options = platform.endSessionOptions.single;
      expect(options.android.useAuthTab, OidcAuthTabMode.never);
      expect(options.ios.prefersEphemeralWebBrowserSession, isFalse);
    });

    test('without a hint, the URL has no id_token_hint, even after a sign-in', () async {
      final client = newClient();
      await signIn(client);

      await client.endProviderSession();

      expect(platform.lastEndSessionUri.queryParameters, isNot(contains('id_token_hint')));
      expect(platform.lastEndSessionUri.queryParameters, contains('client_id'));
    });

    test('an Auth0 issuer with no end_session_endpoint uses /v2/logout with returnTo', () async {
      final auth0 = FakeProvider(issuer: 'https://tenant.eu.auth0.com/', endSessionEndpoint: false);
      final client = newClient(at: auth0, settings: settingsFor(auth0));

      final outcome = await client.endProviderSession(idTokenHint: 'id-token-value');

      expect(outcome, isA<ProviderSessionEnded>());
      final uri = platform.lastEndSessionUri;
      expect(uri.replace(query: ''), Uri.parse('https://tenant.eu.auth0.com/v2/logout?'));
      expect(uri.queryParameters['client_id'], fakeClientId);
      expect(uri.queryParameters['returnTo'], 'org.libredb.mobile:/oauth2redirect');
      expect(uri.queryParameters['post_logout_redirect_uri'], 'org.libredb.mobile:/oauth2redirect');
    });

    test('the auth0.com host itself also uses /v2/logout', () async {
      final auth0 = FakeProvider(issuer: 'https://auth0.com/', endSessionEndpoint: false);

      final outcome = await newClient(at: auth0, settings: settingsFor(auth0)).endProviderSession();

      expect(outcome, isA<ProviderSessionEnded>());
      expect(platform.lastEndSessionUri.path, '/v2/logout');
    });

    test('a host that only contains auth0.com is not Auth0', () async {
      final other = FakeProvider(issuer: 'https://notauth0.com/', endSessionEndpoint: false);

      expect(await newClient(at: other, settings: settingsFor(other)).endProviderSession(), isA<NoProviderLogout>());
    });

    test('no endpoint gives NoProviderLogout and opens nothing', () async {
      final google = FakeProvider(issuer: 'https://accounts.idp.test', endSessionEndpoint: false);

      final outcome = await newClient(at: google, settings: settingsFor(google)).endProviderSession();

      expect(outcome, isA<NoProviderLogout>());
      expect(platform.endSessionRequests, isEmpty);
    });

    test('a platform OidcException gives ProviderLogoutFailed', () async {
      platform.endSession = FakeEndSession.fails;

      expect(await newClient().endProviderSession(idTokenHint: 'id-token-value'), isA<ProviderLogoutFailed>());
    });

    test('a native null answer, the user closing the browser, gives ProviderLogoutFailed', () async {
      platform.endSession = FakeEndSession.nullAnswer;

      expect(await newClient().endProviderSession(), isA<ProviderLogoutFailed>());
    });

    test('discovery unreachable gives ProviderLogoutFailed', () async {
      provider.discoveryAnswer = () => throw http.ClientException('connection refused');

      expect(await newClient().endProviderSession(), isA<ProviderLogoutFailed>());
    });
  });

  // An https issuer whose discovery names an http endpoint would send the code, the PKCE verifier, the refresh token
  // or the ID token hint over plain http (#218); neither the client nor oidc_core checked it.
  group('discovery endpoints', () {
    const endpoints = [
      'authorization_endpoint',
      'token_endpoint',
      'jwks_uri',
      'end_session_endpoint',
      'pushed_authorization_request_endpoint',
    ];

    // Requiring pushed authorization makes the client send the authorization request to that endpoint first.
    void discoveryWith(String key, Object value) {
      provider.discoveryAnswer = () => http.Response(
        jsonEncode({...provider.discovery, 'require_pushed_authorization_requests': true, key: value}),
        200,
      );
    }

    String httpVersion(String key) =>
        '${provider.discovery[key] ?? '${provider.issuer}/protocol/openid-connect/ext/par/request'}'.replaceFirst(
          'https://',
          'http://',
        );

    test('a sign-in refuses an endpoint that is not https before it opens the browser, logging only its key', () async {
      for (final key in endpoints) {
        for (final value in [httpVersion(key), '/relative/path', 'https:///no-host']) {
          discoveryWith(key, value);
          late OidcSignInOutcome outcome;
          // A fresh store each time, since the store keeps a discovery document for five minutes.
          final client = newClient(transactionStore: OidcTransactionStore());
          final lines = await printedLines(() async => outcome = await signIn(client));

          expect(outcome, _failed(OidcFailure.insecureEndpoint), reason: '$key=$value');
          expect(platform.authorizeRequests, isEmpty, reason: '$key=$value');
          expect(provider.requests.where((request) => request.method == 'POST'), isEmpty, reason: '$key=$value');
          expect(lines.where((line) => line.contains(key)), isNotEmpty, reason: 'no line names $key');
          expect(lines.where((line) => line.contains(value)), isEmpty, reason: 'a line printed $value');
        }
      }
    });

    test('a refresh sends no refresh token to an http token endpoint and keeps the session', () async {
      discoveryWith('token_endpoint', httpVersion('token_endpoint'));

      late TokenRotationResult result;
      final lines = await printedLines(
        () async => result = await newClient().refresh(
          refreshToken: 'refresh-old-value',
          idToken: provider.signIdToken(),
          accessToken: 'access-old-value',
          accessTokenExpiresAt: clock.now().toUtc(),
        ),
      );

      expect(result, isA<RotationUnavailable>());
      expect(lines.where((line) => line.contains('token_endpoint')), isNotEmpty, reason: 'no line names the key');
      expect(provider.requests.where((request) => request.method == 'POST'), isEmpty);
    });

    test('a provider logout never opens an http end_session_endpoint', () async {
      discoveryWith('end_session_endpoint', httpVersion('end_session_endpoint'));

      late OidcLogoutOutcome outcome;
      final lines = await printedLines(
        () async => outcome = await newClient().endProviderSession(idTokenHint: 'id-token-value'),
      );

      expect(outcome, isA<ProviderLogoutFailed>());
      expect(platform.endSessionOptions, isEmpty);
      expect(lines.where((line) => line.contains('end_session_endpoint')), isNotEmpty, reason: 'no line names the key');
    });

    test('an https discovery without an end_session_endpoint signs in', () async {
      final noLogout = FakeProvider(endSessionEndpoint: false);
      installFakePlatform(noLogout);
      expect(await signIn(newClient(at: noLogout)), isA<OidcSignedIn>());
    });

    test('a loopback http issuer, never in a prod build, may name http endpoints on its own host', () async {
      final local = FakeProvider(issuer: 'http://localhost:8080/realms/demo');
      installFakePlatform(local);
      expect(await signIn(newClient(at: local)), isA<OidcSignedIn>());
    });

    test('a loopback http issuer may not name an http endpoint on another host', () async {
      final local = FakeProvider(issuer: 'http://localhost:8080/realms/demo');
      installFakePlatform(local);
      local.discoveryAnswer = () =>
          http.Response(jsonEncode({...local.discovery, 'token_endpoint': 'http://idp.example.test/token'}), 200);
      expect(await signIn(newClient(at: local)), _failed(OidcFailure.insecureEndpoint));
    });
  });

  group('oidcRequestRole', () {
    const issuer = 'https://idp.example/realms/demo';
    final discoveryUri = Uri.parse('$issuer/.well-known/openid-configuration');
    final discovered = {
      'issuer': issuer,
      'authorization_endpoint': '$issuer/protocol/openid-connect/auth',
      'pushed_authorization_request_endpoint': '$issuer/protocol/openid-connect/ext/par/request',
      'token_endpoint': '$issuer/protocol/openid-connect/token',
      'jwks_uri': '$issuer/protocol/openid-connect/certs',
      'userinfo_endpoint': '$issuer/protocol/openid-connect/userinfo',
      'revocation_endpoint': '$issuer/protocol/openid-connect/revoke',
      'end_session_endpoint': '$issuer/protocol/openid-connect/logout',
    };

    String roleOf(String url, {Map<String, dynamic>? metadata}) =>
        oidcRequestRole(Uri.parse(url), discoveryUri: discoveryUri, discovered: metadata ?? discovered);

    test('names each endpoint the request targets, a GET to UserInfo included', () {
      expect(roleOf('$issuer/.well-known/openid-configuration'), 'discovery');
      expect(roleOf('$issuer/protocol/openid-connect/token'), 'token');
      expect(roleOf('$issuer/protocol/openid-connect/certs'), 'jwks');
      expect(roleOf('$issuer/protocol/openid-connect/userinfo'), 'userinfo');
      expect(roleOf('$issuer/protocol/openid-connect/ext/par/request'), 'pushed_authorization_request');
      expect(roleOf('$issuer/protocol/openid-connect/revoke'), 'revocation');
    });

    test('ignores the query and the fragment of the request', () {
      expect(roleOf('$issuer/protocol/openid-connect/certs?kid=1#keys'), 'jwks');
    });

    test('names discovery before the discovery document is known', () {
      expect(oidcRequestRole(discoveryUri, discoveryUri: discoveryUri, discovered: null), 'discovery');
    });

    test('is unknown for a URL that no endpoint names, or before discovery, never a guess', () {
      expect(roleOf('$issuer/protocol/openid-connect/other'), 'unknown');
      expect(roleOf('https://other.example/realms/demo/protocol/openid-connect/token'), 'unknown');
      expect(roleOf('http://idp.example/realms/demo/protocol/openid-connect/token'), 'unknown');
      expect(
        oidcRequestRole(
          Uri.parse('$issuer/protocol/openid-connect/token'),
          discoveryUri: discoveryUri,
          discovered: null,
        ),
        'unknown',
      );
    });
  });

  // oidc_core takes any status under 400 as success, and package:http follows redirects by default, so a 302 from the
  // https issuer to plain http would fetch discovery or the JWKS over http, where a hop could name its own https
  // endpoints that pass the endpoint check (#218). Real sockets, so the redirect is the one dart:io would follow.
  group('a redirect from the identity provider', () {
    late int plainRequests;
    late HttpServer plain;
    late HttpServer issuerServer;
    late FakeProvider tlsProvider;
    late FakeOidcPlatform tlsPlatform;

    /// Starts the plain http server a redirect points to and the https issuer, which answers as [tlsProvider] does
    /// except for a request whose path ends with [redirected], which it sends to the plain server with a 302.
    Future<void> start({required String redirected}) async {
      plainRequests = 0;
      plain = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => plain.close(force: true));
      issuerServer = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, loopbackServerContext());
      addTearDown(() => issuerServer.close(force: true));
      tlsProvider = FakeProvider(issuer: 'https://127.0.0.1:${issuerServer.port}/realms/demo');
      tlsPlatform = installFakePlatform(tlsProvider);
      Future<void> forward(HttpRequest request) async {
        final forwarded =
            http.Request(request.method, Uri.parse('${tlsProvider.issuer.split('/realms').first}${request.uri}'))
              ..headers.addAll({
                for (final name in ['content-type', 'authorization']) name: ?request.headers.value(name),
              })
              ..bodyBytes = await request.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
        final answer = await http.Response.fromStream(await tlsProvider.client.send(forwarded));
        request.response
          ..statusCode = answer.statusCode
          ..headers.contentType = ContentType.json
          ..add(answer.bodyBytes);
        await request.response.close();
      }

      plain.listen((request) async {
        plainRequests++;
        await forward(request);
      });
      issuerServer.listen((request) async {
        if (request.uri.path.endsWith(redirected)) {
          await request.drain<void>();
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set('location', 'http://127.0.0.1:${plain.port}${request.uri}');
          await request.response.close();
          return;
        }
        await forward(request);
      });
    }

    OidcClient trustingClient() => OidcClient(
      settings: settingsFor(tlsProvider),
      store: store,
      httpClient: IOClient(
        HttpClient(
          context: SecurityContext(withTrustedRoots: false)
            ..setTrustedCertificatesBytes(utf8.encode(loopbackCertificatePem)),
        ),
      ),
      platform: OidcPlatformKind.ios,
    );

    test('at discovery is not followed, so nothing goes over http and the sign-in fails as discovery', () async {
      await start(redirected: '/.well-known/openid-configuration');
      late OidcSignInOutcome outcome;
      final lines = await printedLines(() async => outcome = await withRealSockets(() => trustingClient().signIn()));

      expect(outcome, _failed(OidcFailure.discovery));
      expect(plainRequests, 0, reason: 'discovery was fetched over http');
      expect(tlsPlatform.authorizeRequests, isEmpty);
      expect(lines.where((line) => line.contains('discovery') && line.contains('redirect')), isNotEmpty);
      expect(lines.where((line) => line.contains('${plain.port}')), isEmpty, reason: 'a line printed the Location');
    });

    test('at the JWKS is not followed, so the keys never come over http and the sign-in fails', () async {
      await start(redirected: '/certs');
      late OidcSignInOutcome outcome;
      final lines = await printedLines(() async => outcome = await withRealSockets(() => trustingClient().signIn()));

      expect(outcome, _failed(OidcFailure.discovery));
      expect(plainRequests, 0, reason: 'the JWKS was fetched over http');
      expect(lines.where((line) => line.contains('jwks') && line.contains('redirect')), isNotEmpty);
      expect(lines.where((line) => line.contains('${plain.port}')), isEmpty, reason: 'a line printed the Location');
    });

    test('at the token endpoint is not followed, so no code goes over http and the sign-in fails', () async {
      await start(redirected: '/token');
      late OidcSignInOutcome outcome;
      final lines = await printedLines(() async => outcome = await withRealSockets(() => trustingClient().signIn()));

      expect(outcome, _failed(OidcFailure.failed));
      expect(plainRequests, 0, reason: 'the code was sent over http');
      expect(lines.where((line) => line.contains('token request') && line.contains('redirect')), isNotEmpty);
      expect(lines.where((line) => line.contains('${plain.port}')), isEmpty, reason: 'a line printed the Location');
      await expectStoreEmpty();
    });

    test('at the token endpoint during a refresh is not followed and keeps the session', () async {
      await start(redirected: '/token');
      late TokenRotationResult result;
      final lines = await printedLines(
        () async => result = await withRealSockets(
          () => trustingClient().refresh(
            refreshToken: 'refresh-old-value',
            idToken: tlsProvider.signIdToken(),
            accessToken: 'access-old-value',
            accessTokenExpiresAt: clock.now().toUtc().subtract(const Duration(seconds: 5)),
          ),
        ),
      );

      expect(result, isA<RotationUnavailable>());
      expect(plainRequests, 0, reason: 'the refresh token was sent over http');
      expect(lines.where((line) => line.contains('token request') && line.contains('redirect')), isNotEmpty);
      expect(lines.where((line) => line.contains('${plain.port}')), isEmpty, reason: 'a line printed the Location');
    });

    test('without a redirect the same setup signs in and refreshes, so the failures above are the redirect', () async {
      await start(redirected: '/nothing-is-redirected');
      expect(await withRealSockets(() => trustingClient().signIn()), isA<OidcSignedIn>());
      final refreshed = await withRealSockets(
        () => trustingClient().refresh(
          refreshToken: 'refresh-old-value',
          idToken: tlsProvider.signIdToken(),
          accessToken: 'access-old-value',
          accessTokenExpiresAt: clock.now().toUtc().subtract(const Duration(seconds: 5)),
        ),
      );
      expect(refreshed, isA<TokensRotated>());
      expect(plainRequests, 0);
    });
  });
}

Matcher _failed(OidcFailure failure) =>
    isA<OidcSignInFailed>().having((outcome) => outcome.failure, 'failure', failure);

/// A transaction store whose first clear throws, as a sign-in ends, so that sign-in rejects with it.
final class _ClearFailsOnceStore extends OidcTransactionStore {
  bool _failed = false;

  @override
  Future<void> clearTransactions() async {
    if (!_failed) {
      _failed = true;
      throw StateError('The store could not be cleared');
    }
    await super.clearTransactions();
  }
}
