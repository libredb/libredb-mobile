@Tags(['widget'])
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/features/auth/application/session_target_switch_bloc.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_sign_out_auth_repository.dart';
import 'package:libredb_mobile/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/auth/data/services/sso_session_startup_impl.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_transaction_store.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:logging/logging.dart' as logging;

import '../../infrastructure/auth/oidc/support/fake_provider.dart';
import '../../support/printed_lines.dart';
import '../../support/test_env.dart';

final _settings = OidcSettings(issuer: Uri.parse(fakeIssuer), clientId: fakeClientId);

/// The test config whose client talks to [provider] through the fake platform.
class _OidcDependencies extends AppDependencies {
  _OidcDependencies(this.provider) : super(appConfig: const AppConfig.test(), authMode: OidcAuthMode(_settings));

  final FakeProvider provider;

  @override
  IOidcClient createOidcClient(OidcSettings settings, {List<String> Function()? uiLocales}) => OidcClient(
    settings: settings,
    store: OidcTransactionStore(),
    httpClient: provider.client,
    platform: OidcPlatformKind.ios,
    cancelAndroidFlow: () async => fail('an iOS sign-in never cancels an Android flow'),
  );
}

/// The API server: 401 to a request whose bearer is in [rejected], as to an expired access token, and 200 to any
/// other, so the request never reaches the mock interceptor behind it.
class _ServerStub extends Interceptor {
  final rejected = <String>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final authorization = options.headers['Authorization'] as String?;
    if (authorization != null && rejected.contains(authorization.replaceFirst('Bearer ', ''))) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 401),
        ),
        true,
      );
      return;
    }
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: '{}'));
  }
}

/// Every line the three log sources give while [body] runs: what the zone prints (AppLogger's console output among
/// it), the output events of package:logger, and each package:logging record at every level, with its error and
/// stack trace.
Future<List<String>> _capturedLogs(Future<void> Function() body) async {
  final loggerLines = <String>[];
  void collect(OutputEvent event) => loggerLines.addAll(event.lines);
  Logger.addOutputListener(collect);
  addTearDown(() => Logger.removeOutputListener(collect));

  final records = <String>[];
  final rootLevel = logging.Logger.root.level;
  logging.Logger.root.level = logging.Level.ALL;
  addTearDown(() => logging.Logger.root.level = rootLevel);
  final subscription = logging.Logger.root.onRecord.listen((record) {
    records.add('${record.loggerName}/${record.level.name}: ${record.message}');
    if (record.error case final error?) records.add(error.toString());
    if (record.stackTrace case final stackTrace?) records.add(stackTrace.toString());
  });
  addTearDown(subscription.cancel);

  final printed = await printedLines(body);
  return [...printed, ...loggerLines, ...records];
}

void _expectNoSecret(List<String> lines, Set<String> secrets) {
  for (final secret in secrets) {
    expect(secret, isNotEmpty);
    final leaks = [
      for (final line in lines)
        if (line.contains(secret)) line,
    ];
    expect(leaks, isEmpty, reason: 'a log line carries the secret $secret');
  }
}

void main() {
  test('a sign-in, a refresh, a logout and their failures log no token, code, verifier, state or nonce', () async {
    final provider = FakeProvider();
    final platform = installFakePlatform(provider);
    final issued = <String>{};
    http.Response recordTokens(http.Response answer) {
      final body = jsonDecode(answer.body) as Map<String, dynamic>;
      for (final key in const ['access_token', 'refresh_token', 'id_token']) {
        if (body[key] case final String token) issued.add(token);
      }
      return answer;
    }

    provider
      ..codeAnswer = (() => recordTokens(provider.tokenAnswer(nonce: provider.nonce)))
      ..refreshAnswer = (() => recordTokens(provider.tokenAnswer()));

    final dependencies = _OidcDependencies(provider);
    final secureStorage = FlutterSecureStorageAdapter();
    final client = dependencies.createOidcClient(_settings);
    final sessions = dependencies.createAuthSessionRepository(secureStorage);
    final rotation = dependencies.createOidcTokenRotation(client, secureStorage);
    var sessionsExpired = 0;
    final apiClient = dependencies.createApiClient(
      secureStorage,
      onSessionExpired: () async {
        sessionsExpired++;
        await sessions.clear();
      },
      tokenRotation: rotation,
    );
    final server = _ServerStub();
    final dio = apiClient.instance;
    dio.interceptors.insert(dio.interceptors.length - 1, server);
    final ssoRepository = dependencies.createSsoAuthRepository(client, sessions);
    final signOutRepository = SsoSignOutAuthRepository(
      inner: dependencies.createAuthRepository(sessions),
      client: client,
      secureStorage: secureStorage,
      settings: _settings,
      studioIdentity: StudioIdentityRepository(apiClient),
      sessionRefresh: SsoSessionStartup(
        rotation: rotation,
        secureStorage: secureStorage,
        sessionRepository: sessions,
        gate: SsoAutoRedirectGate(),
      ),
    );
    Future<String?> stored(SecureStorageKeys key) => secureStorage.read(key.key);
    // The error a caller of the API gets, which a page or a BLoC may log in turn.
    Object? apiError;

    final lines = await _capturedLogs(() async {
      // A code exchange the provider refuses.
      final defaultCodeAnswer = provider.codeAnswer;
      provider.codeAnswer = () => FakeProvider.errorAnswer('invalid_grant');
      expect(await ssoRepository.signIn(target: SessionTarget.studio), isA<SsoProviderRejected>());
      provider.codeAnswer = defaultCodeAnswer;

      // A sign-in, then a 401 that a refresh fixes.
      expect(await ssoRepository.signIn(target: SessionTarget.studio), isA<SsoProviderSignedIn>());
      server.rejected.add((await stored(SecureStorageKeys.jwtToken))!);
      expect((await apiClient.get('/connections/managed')).statusCode, 200);
      expect(provider.tokenRequests, hasLength(3));

      // A logout that ends the provider session with the refreshed ID token as its hint.
      expect(await signOutRepository.logout(), isA<Success<void>>());
      expect(issued, contains(platform.endSessionRequests.single.idTokenHint));

      // A sign-in, then a 401 whose refresh the provider refuses, which ends the session.
      expect(await ssoRepository.signIn(target: SessionTarget.studio), isA<SsoProviderSignedIn>());
      server.rejected.add((await stored(SecureStorageKeys.jwtToken))!);
      provider.refreshAnswer = () => FakeProvider.errorAnswer('invalid_grant');
      apiError = await apiClient
          .get('/connections/managed')
          .then<Object?>((_) => null, onError: (Object error) => error);
      expect(apiError, isNotNull);
      expect(sessionsExpired, 1);
      expect(await stored(SecureStorageKeys.jwtToken), isNull);
    });

    expect(issued, hasLength(9), reason: 'three token answers, each with an access, a refresh and an ID token');
    final verifiers = [for (final request in provider.tokenRequests) ?FakeProvider.form(request)['code_verifier']];
    expect(verifiers, hasLength(3), reason: 'three code exchanges, the refused one among them');
    expect(platform.authorizeRequests, hasLength(3));
    expect(lines, contains(contains('Signed in through the identity provider')), reason: 'the capture saw no log');
    // The stub answers the logout record with `{}`, so the sign-out's one warn line for a missed record is among them.
    expect(
      lines,
      contains(contains('Studio has no record of this sign-out')),
      reason: 'the missed record went unlogged',
    );
    _expectNoSecret(
      [...lines, apiError.toString()],
      {
        ...issued,
        FakeOidcPlatform.code,
        for (final request in platform.authorizeRequests) ...[request.state!, request.nonce!],
        ...verifiers,
      },
    );
  });

  // .team decision '2026-10-25: #18 amendment for Platform sign-out': a Platform sign-out writes no Studio record and
  // no warn line about it, and a Studio sign-out that misses its record still writes exactly one.
  test('a Platform sign-out writes no warn line, and a Studio sign-out without a record writes exactly one', () async {
    final provider = FakeProvider();
    installFakePlatform(provider);
    provider.codeAnswer = () => provider.tokenAnswer(nonce: provider.nonce);

    final dependencies = _OidcDependencies(provider);
    final secureStorage = FlutterSecureStorageAdapter();
    final client = dependencies.createOidcClient(_settings);
    final sessions = dependencies.createAuthSessionRepository(secureStorage);
    final rotation = dependencies.createOidcTokenRotation(client, secureStorage);
    final apiClient = dependencies.createApiClient(
      secureStorage,
      onSessionExpired: () async => sessions.clear(),
      tokenRotation: rotation,
    );
    final server = _ServerStub();
    final dio = apiClient.instance;
    final studioRequests = <String>[];
    dio.interceptors.insert(
      dio.interceptors.length - 1,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          studioRequests.add(options.path);
          handler.next(options);
        },
      ),
    );
    dio.interceptors.insert(dio.interceptors.length - 1, server);
    final ssoRepository = dependencies.createSsoAuthRepository(client, sessions);
    final signOutRepository = SsoSignOutAuthRepository(
      inner: dependencies.createAuthRepository(sessions),
      client: client,
      secureStorage: secureStorage,
      settings: _settings,
      studioIdentity: StudioIdentityRepository(apiClient),
      sessionRefresh: SsoSessionStartup(
        rotation: rotation,
        secureStorage: secureStorage,
        sessionRepository: sessions,
        gate: SsoAutoRedirectGate(),
      ),
    );
    List<String> warnLines(List<String> lines) => [
      for (final line in lines)
        if (line.contains('SsoSignOutAuthRepository') && line.contains('[W]')) line,
    ];

    expect(await ssoRepository.signIn(target: SessionTarget.platform), isA<SsoProviderSignedIn>());
    // The printed lines only: _capturedLogs also gives each AppLogger line again through package:logger's listener.
    final platformLines = await printedLines(() async {
      expect(await signOutRepository.logout(), isA<Success<void>>());
    });

    expect(warnLines(platformLines), isEmpty);
    expect(studioRequests, isEmpty, reason: 'a Platform sign-out sends nothing to Studio');
    expect(await secureStorage.read(SecureStorageKeys.jwtToken.key), isNull);

    // The stub answers the logout record with `{}`, which Studio's record refuses.
    expect(await ssoRepository.signIn(target: SessionTarget.studio), isA<SsoProviderSignedIn>());
    final studioLines = await printedLines(() async {
      expect(await signOutRepository.logout(), isA<Success<void>>());
    });

    expect(warnLines(studioLines), [contains('Studio has no record of this sign-out')]);
    expect(studioRequests, isNotEmpty);
  });

  // .team decision '2026-10-25: M11-P rulings': a mode switch is no sign-out, so it records nothing at Studio, starts
  // no provider end-session and writes no warn line.
  testWidgets('a mode switch both ways sends no Studio logout record, no provider end-session and no warn line', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate();
    final dependencies = _SwitchDependencies();

    final lines = await printedLines(() async {
      await tester.pumpWidget(App(language: 'en', dependencies: dependencies));
      await tester.pumpAndSettle();
      final app = tester.element(find.byType(MaterialApp));
      for (final to in [SessionTarget.platform, SessionTarget.studio]) {
        app.read<SessionTargetSwitchBloc>().add(SessionTargetSwitchRequested(to));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(app.read<SessionCubit>().state, SessionAuthenticated(target: to));
      }
      await tester.pumpWidget(const SizedBox());
    });

    expect(lines.where((line) => line.contains('The session switched to platform')), hasLength(1));
    expect(lines.where((line) => line.contains('The session switched to studio')), hasLength(1));
    expect(lines.where((line) => line.contains('[W]')), isEmpty);
    expect(dependencies.signOutRecords, 0);
    expect(dependencies.providerLogouts, 0);
  });

  testWidgets('a callback URL the platform pushes logs neither its code nor its state', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    final provider = FakeProvider();
    installFakePlatform(provider);

    final lines = await _capturedLogs(() async {
      await tester.pumpWidget(App(language: 'en', dependencies: _OidcDependencies(provider)));
      await tester.pumpAndSettle();

      // The platform pushes a route the way iOS delivers a custom scheme link (app_router_test.dart).
      final message = SystemChannels.navigation.codec.encodeMethodCall(
        const MethodCall('pushRouteInformation', <String, Object?>{
          'location': '/oauth2redirect?code=SECRETCODE&state=SECRETSTATE',
          'state': null,
        }),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.navigation.name,
        message,
        (_) {},
      );
      await tester.pumpAndSettle();
    });

    expect(find.byType(LoginScreen), findsOneWidget);
    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
    expect(router.state.uri.toString(), ApplicationRoutesConstants.login);
    expect(lines, isNotEmpty, reason: 'the capture saw no log');
    _expectNoSecret(lines, {'SECRETCODE', 'SECRETSTATE'});
  });
}

/// The mock sign-in in a build with a Platform target, counting the Studio logout records and the provider
/// end-sessions it is asked for.
class _SwitchDependencies extends MockSignInDependencies {
  _SwitchDependencies() : super(appConfig: const AppConfig.test());

  int signOutRecords = 0;
  int providerLogouts = 0;

  @override
  IStudioIdentityRepository createStudioIdentityRepository(ApiClient apiClient) =>
      _CountingStudioIdentity(super.createStudioIdentityRepository(apiClient), () => signOutRecords++);

  @override
  IOidcClient createOidcClient(OidcSettings settings, {List<String> Function()? uiLocales}) =>
      _CountingOidcClient(super.createOidcClient(settings), () => providerLogouts++);
}

class _CountingStudioIdentity implements IStudioIdentityRepository {
  _CountingStudioIdentity(this._inner, this._onRecord);

  final IStudioIdentityRepository _inner;
  final void Function() _onRecord;

  @override
  Future<Result<StudioIdentity>> fetch({bool probe = false}) => _inner.fetch(probe: probe);

  @override
  Future<Result<void>> recordSignOut() {
    _onRecord();
    return _inner.recordSignOut();
  }
}

class _CountingOidcClient implements IOidcClient {
  _CountingOidcClient(this._inner, this._onLogout);

  final IOidcClient _inner;
  final void Function() _onLogout;

  @override
  Future<OidcSignInOutcome> signIn() => _inner.signIn();

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => _inner.refresh(
    refreshToken: refreshToken,
    idToken: idToken,
    accessToken: accessToken,
    accessTokenExpiresAt: accessTokenExpiresAt,
  );

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) {
    _onLogout();
    return _inner.endProviderSession(idTokenHint: idTokenHint);
  }
}
