@Tags(['widget'])
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/session/platform_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/shell/account_refusal/studio_account_refusal_page.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/account_refusal_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/token_refresh_interceptor.dart';
import 'package:libredb_mobile/features/platform_home/presentation/pages/platform_home_page.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

import '../../../support/test_env.dart';

const _refusalTitle = 'LibreDB Platform refused your account';

void main() {
  late _RefusingPlatform platform;

  setUp(() => platform = _RefusingPlatform());

  // The real app on the mock API, signed in to Platform, with Platform refusing the account on platform.refused.
  Future<void> pumpSignedIn(WidgetTester tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate(target: SessionTarget.platform);

    await tester.pumpWidget(App(dependencies: _RefusingPlatformDependencies(platform), language: 'en'));
    await tester.pumpAndSettle();
    // The refusal page animates nothing, so the settle can end before the mock answers the identity it delays.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  BuildContext appContext(WidgetTester tester) => tester.element(find.byType(MaterialApp));

  Future<void> requestPlatform(WidgetTester tester, String path) async {
    final client = appContext(tester).read<PlatformApiClient>();
    await tester.runAsync(() => client.get(path).then<void>((_) {}, onError: (Object _) {}));
    await tester.pumpAndSettle();
  }

  testWidgets('an admin Platform refuses when the shell opens sees the refusal page instead of the tabs', (
    tester,
  ) async {
    platform.refused.add('/v1/me');

    await pumpSignedIn(tester);

    expect(find.byType(StudioAccountRefusalPage), findsOneWidget);
    expect(find.text(_refusalTitle), findsOneWidget);
    expect(find.text('This account is not a Platform admin. Sign in through Studio instead.'), findsOneWidget);
    expect(find.byType(ResponsiveScaffold), findsNothing);
    expect(find.byType(ResponsiveScaffold, skipOffstage: false), findsOneWidget, reason: 'the screens stay mounted');
    expect(appContext(tester).read<SessionCubit>().state, const SessionAuthenticated(target: SessionTarget.platform));
  });

  for (final (code, message) in [
    ('ADMIN_ROLE_REQUIRED', 'This account is not a Platform admin. Sign in through Studio instead.'),
    ('LICENSE_ADMIN_SEATS', 'The Platform license has no free admin seat for this account.'),
  ]) {
    testWidgets('a 403 $code met later covers the screens with the refusal page', (tester) async {
      await pumpSignedIn(tester);
      expect(find.byType(ResponsiveScaffold), findsOneWidget);
      platform
        ..code = code
        ..refused.add('/v1/connections');

      await requestPlatform(tester, '/v1/connections');

      expect(find.byType(StudioAccountRefusalPage), findsOneWidget);
      expect(find.text(_refusalTitle), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.byType(ResponsiveScaffold), findsNothing);
    });
  }

  testWidgets('a 403 LICENSE_USER_SEATS on a Platform request leaves the screens uncovered', (tester) async {
    await pumpSignedIn(tester);
    platform
      ..code = 'LICENSE_USER_SEATS'
      ..refused.add('/v1/connections');

    await requestPlatform(tester, '/v1/connections');

    expect(find.byType(StudioAccountRefusalPage), findsNothing);
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    expect(appContext(tester).read<PlatformAccountRefusalCubit>().state, const PlatformAccountAccepted());
  });

  testWidgets('Retry reloads the identity, shows progress, and a 200 uncovers the screens with their state kept', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    final scaffold = tester.element(find.byType(ResponsiveScaffold));
    platform.refused.addAll(['/v1/me', '/v1/connections']);
    await requestPlatform(tester, '/v1/connections');
    expect(find.byType(StudioAccountRefusalPage), findsOneWidget);
    final askedBefore = platform.requests.where((path) => path == '/v1/me').length;

    platform.refused.clear();
    await tester.tap(find.byKey(accountRefusalRetryKey));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(accountRefusalRetryKey)).onPressed,
      isNull,
      reason: 'Retry shows progress while the identity loads',
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(platform.requests.where((path) => path == '/v1/me'), hasLength(askedBefore + 1));
    expect(find.byType(StudioAccountRefusalPage), findsNothing);
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    expect(tester.element(find.byType(ResponsiveScaffold)), same(scaffold), reason: 'the screens kept their state');
    expect(find.byType(PlatformHomePage), findsOneWidget);
    expect(appContext(tester).read<PlatformAccountRefusalCubit>().state, const PlatformAccountAccepted());
    expect(appContext(tester).read<PlatformIdentityCubit>().state, isA<PlatformIdentityLoaded>());
  });

  testWidgets('Retry while Platform still refuses keeps the page', (tester) async {
    platform.refused.add('/v1/me');
    await pumpSignedIn(tester);

    await tester.tap(find.byKey(accountRefusalRetryKey));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(StudioAccountRefusalPage), findsOneWidget);
    expect(platform.requests.where((path) => path == '/v1/me'), hasLength(2));
  });

  testWidgets('Logout asks for confirmation and signs out, and the next user starts with no refusal', (tester) async {
    platform.refused.add('/v1/me');
    await pumpSignedIn(tester);

    await tester.tap(find.byKey(accountRefusalSignOutKey));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(appContext(tester).read<SessionCubit>().state, isA<SessionUnauthenticated>());
    expect(appContext(tester).read<PlatformAccountRefusalCubit>().state, const PlatformAccountAccepted());
    expect(appContext(tester).read<PlatformIdentityCubit>().state, const PlatformIdentityInitial());
  });

  test('the refusal codes are the two account codes of Platform', () {
    expect({AppErrorCode.platformAdminRoleRequired, AppErrorCode.platformLicenseAdminSeats}.map((code) => code.key), {
      'platform.admin_role_required',
      'platform.license_admin_seats',
    });
  });
}

/// Platform answering 403 with [code] in its error envelope on the [refused] paths; the mock API answers every other
/// request. Records the paths it is sent.
class _RefusingPlatform extends Interceptor {
  final refused = <String>{};
  final requests = <String>[];
  String code = 'ADMIN_ROLE_REQUIRED';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options.path);
    if (!refused.contains(options.path)) return handler.next(options);
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: 403,
          data: '{"error":{"code":"$code","message":"refused for a reason the app never shows"}}',
        ),
      ),
      true,
    );
  }
}

/// The mock-backed app, with [platform] answering before the mock does on the Platform client.
class _RefusingPlatformDependencies extends LocalSignInDependencies {
  _RefusingPlatformDependencies(this.platform);

  final _RefusingPlatform platform;

  @override
  PlatformApiClient createPlatformApiClient(
    ISecureStorage secureStorage, {
    required OnSessionExpired onSessionExpired,
    OnAccountRefused? onAccountRefused,
    required TokenRotation tokenRotation,
  }) {
    final client = super.createPlatformApiClient(
      secureStorage,
      onSessionExpired: onSessionExpired,
      onAccountRefused: onAccountRefused,
      tokenRotation: tokenRotation,
    );
    // Sits first, so every other interceptor sees its refusal on the way back as a real answer.
    client.instance.interceptors.insert(0, platform);
    return client;
  }
}
