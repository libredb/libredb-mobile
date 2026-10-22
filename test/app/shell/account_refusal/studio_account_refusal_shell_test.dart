@Tags(['widget'])
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/account_refusal/studio_account_refusal_page.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

import '../../../support/test_env.dart';

void main() {
  late _RefusingStudio studio;

  setUp(() => studio = _RefusingStudio());

  // The real app on the mock API, signed in, with Studio refusing the account on the routes in studio.refused.
  Future<void> pumpSignedIn(WidgetTester tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate();

    await tester.pumpWidget(App(dependencies: _RefusingStudioDependencies(studio), language: 'en'));
    await tester.pumpAndSettle();
    // The refusal page animates nothing, so the settle can end before the mock answers the startup checks it delays.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  BuildContext appContext(WidgetTester tester) => tester.element(find.byType(MaterialApp));

  testWidgets('an account Studio refuses when the shell opens sees the refusal page instead of the tabs', (
    tester,
  ) async {
    studio.refused.addAll(['/auth/me', '/connections/managed', '/connections/policy']);

    await pumpSignedIn(tester);

    expect(find.byType(StudioAccountRefusalPage), findsOneWidget);
    expect(find.text('Your account has no access to Studio'), findsOneWidget);
    expect(find.text('This account has no role in Studio. Ask an administrator to give it one.'), findsOneWidget);
    expect(find.byType(ResponsiveScaffold), findsNothing);
    expect(appContext(tester).read<SessionCubit>().state, isA<SessionAuthenticated>(), reason: 'the session stays');
  });

  // An administrator removed the role, or the account lost its user name; the next request Studio answers, wherever it
  // comes from, meets the refusal. The page only covers the shell: the session and its tokens stay, for Retry.
  for (final (code, expected) in [
    ('BEARER_NO_ROLE', AppErrorCode.studioAccountHasNoRole),
    ('BEARER_NO_IDENTITY', AppErrorCode.studioAccountHasNoIdentity),
  ]) {
    for (final path in ['/auth/me', '/connections/managed']) {
      testWidgets('a 403 $code met later by $path replaces the screen with the page and keeps the session', (
        tester,
      ) async {
        await pumpSignedIn(tester);
        expect(find.byType(ResponsiveScaffold), findsOneWidget);
        studio
          ..body = '{"error":"refused","code":"$code"}'
          ..refused.add(path);

        final apiClient = appContext(tester).read<ApiClient>();
        await tester.runAsync(() => apiClient.get(path).then<void>((_) {}, onError: (Object _) {}));
        await tester.pumpAndSettle();

        expect(find.byType(StudioAccountRefusalPage), findsOneWidget);
        expect(find.byType(ResponsiveScaffold), findsNothing);
        expect(appContext(tester).read<StudioAccountRefusalCubit>().state, StudioAccountRefused(expected));
        expect(appContext(tester).read<SessionCubit>().state, isA<SessionAuthenticated>());
        final tokens = appContext(tester).read<ISecureStorage>();
        expect(await tester.runAsync(() => tokens.read(SecureStorageKeys.jwtToken.key)), 'MOCK_TOKEN');
      });
    }
  }

  // Studio answers 403 for other reasons too, such as a route only an administrator may use, or a POST it does not
  // trust; those are the screen's to tell, and the tabs stay.
  for (final body in [
    '{"error":"Unauthorized. Admin access required.","code":"ADMIN_REQUIRED"}',
    '{"error":"Origin mismatch","code":"ORIGIN_MISMATCH"}',
    '{"error":"Forbidden"}',
  ]) {
    testWidgets('a 403 $body met later keeps the tabs and the session', (tester) async {
      await pumpSignedIn(tester);
      studio
        ..body = body
        ..refused.add('/connections/managed');

      final apiClient = appContext(tester).read<ApiClient>();
      await tester.runAsync(() => apiClient.get('/connections/managed').then<void>((_) {}, onError: (Object _) {}));
      await tester.pumpAndSettle();

      expect(find.byType(StudioAccountRefusalPage), findsNothing);
      expect(find.byType(ResponsiveScaffold), findsOneWidget);
      expect(appContext(tester).read<StudioAccountRefusalCubit>().state, const StudioAccountAccepted());
      expect(appContext(tester).read<SessionCubit>().state, isA<SessionAuthenticated>());
    });
  }

  testWidgets('Retry asks Studio again and brings the tabs back once it accepts the account', (tester) async {
    studio.refused.addAll(['/auth/me', '/connections/managed', '/connections/policy']);
    await pumpSignedIn(tester);

    await tester.tap(find.byKey(accountRefusalRetryKey));
    await tester.pumpAndSettle();

    expect(find.byType(StudioAccountRefusalPage), findsOneWidget, reason: 'Studio still refuses the account');
    expect(studio.requests.where((path) => path == '/auth/me'), hasLength(2));

    studio.refused.clear();
    await tester.tap(find.byKey(accountRefusalRetryKey));
    await tester.pumpAndSettle();

    expect(find.byType(StudioAccountRefusalPage), findsNothing);
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    expect(appContext(tester).read<StudioAccountRefusalCubit>().state, const StudioAccountAccepted());
  });

  testWidgets('Logout signs out as the profile sheet does, and the next user starts with no refusal', (tester) async {
    studio.refused.addAll(['/auth/me', '/connections/managed', '/connections/policy']);
    await pumpSignedIn(tester);

    await tester.tap(find.byKey(accountRefusalSignOutKey));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    // The app waits for Studio to record the sign-out, which the mock answers after its simulated latency.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(appContext(tester).read<SessionCubit>().state, isA<SessionUnauthenticated>());
    expect(appContext(tester).read<StudioAccountRefusalCubit>().state, const StudioAccountAccepted());
  });
}

/// Studio answering 403 with [body] on the [refused] paths, by default BEARER_NO_ROLE as libredb-studio#1922 does for a
/// Keycloak user without a Studio role; the mock API answers every other request. Records the paths it is sent.
class _RefusingStudio extends Interceptor {
  final refused = <String>{};
  final requests = <String>[];
  String body =
      '{"error":"This account has no role in Studio. Ask an administrator for access.","code":"BEARER_NO_ROLE"}';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options.path);
    if (!refused.contains(options.path)) return handler.next(options);
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 403, data: body),
      ),
      true,
    );
  }
}

/// The mock-backed app, with [studio] answering before the mock does.
class _RefusingStudioDependencies extends LocalSignInDependencies {
  _RefusingStudioDependencies(this.studio);

  final _RefusingStudio studio;

  @override
  ApiClient createApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnAccountRefused? onAccountRefused,
    required TokenRotation tokenRotation,
  }) {
    final client = super.createApiClient(
      secureStorage,
      onSessionExpired: onSessionExpired,
      onAccountRefused: onAccountRefused,
      tokenRotation: tokenRotation,
    );
    // Sits first, so every other interceptor sees its refusal on the way back as a real answer.
    client.instance.interceptors.insert(0, studio);
    return client;
  }
}
