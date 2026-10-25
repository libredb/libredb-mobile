@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/app/shell/sign_out_progress_barrier.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/test_env.dart';
import '../../../support/user_menu.dart';

void main() {
  GoRouter routerOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

  // The real app, signed in, on the connection list, after the mock API has answered.
  Future<void> pumpSignedIn(
    WidgetTester tester, {
    Size size = const Size(1600, 1600),
    String language = 'en',
    double textScale = 1.0,
  }) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    TestEnv.authenticate();

    await tester.pumpWidget(App(dependencies: LocalSignInDependencies(), language: language));
    await tester.pumpAndSettle();
  }

  Finder avatar() => find.byKey(profileButtonKey);
  Finder inSheet(Finder finder) => find.descendant(of: find.byType(ProfileSheet), matching: finder);

  group('TopBarWidget - profile sheet', () {
    testWidgets("the avatar opens the profile sheet with the username and role from Studio's /auth/me", (tester) async {
      await pumpSignedIn(tester);

      await tester.tap(avatar());
      await tester.pumpAndSettle();

      // assets/mock/GET_auth_me.json and GET_connections_policy.json.
      expect(inSheet(find.text('admin@example.com')), findsOneWidget);
      expect(inSheet(find.text('Administrator')), findsOneWidget);
      expect(inSheet(find.widgetWithText(Chip, 'Governed by LibreDB Platform')), findsOneWidget);
    });

    for (final location in const [
      ApplicationRoutesConstants.connectionList,
      ApplicationRoutesConstants.browse,
      ApplicationRoutesConstants.sql,
    ]) {
      testWidgets('Settings opens the settings on top of $location, and the back arrow returns to it', (tester) async {
        await pumpSignedIn(tester);
        routerOf(tester).go(location);
        await tester.pumpAndSettle();

        await selectFromUserMenu(tester, Icons.settings_outlined);

        expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.settings);
        expect(find.byType(SettingsScreen), findsOneWidget);

        await tester.tap(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(BackButton)));
        await tester.pumpAndSettle();

        expect(routerOf(tester).state.uri.path, location);
      });
    }

    testWidgets('the back arrow of settings opened by a link, with nothing under it, opens the connection list', (
      tester,
    ) async {
      await pumpSignedIn(tester);
      routerOf(tester).go(ApplicationRoutesConstants.settings);
      await tester.pumpAndSettle();
      expect(routerOf(tester).canPop(), isFalse);

      await tester.tap(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(BackButton)));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
    });

    testWidgets('a tab has no back arrow', (tester) async {
      await pumpSignedIn(tester);

      expect(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(BackButton)), findsNothing);
    });

    testWidgets('Logout signs the user out and opens the login page with no signed-in page to go back to', (
      tester,
    ) async {
      await pumpSignedIn(tester);

      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.widgetWithText(FilledButton, 'Yes'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.login);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(routerOf(tester).canPop(), isFalse);
      // The app-scoped answers about the user who signed out are gone before the next user signs in.
      final login = tester.element(find.byType(LoginScreen));
      expect(login.read<StudioIdentityCubit>().state, const StudioIdentityInitial());
      expect(login.read<ConnectionPolicyCubit>().state, const ConnectionPolicyInitial());
    });

    testWidgets('after a sign-out and a new sign-in, the shell asks Studio again who the user is', (tester) async {
      await pumpSignedIn(tester);
      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.widgetWithText(FilledButton, 'Yes'));
      await tester.pumpAndSettle();

      TestEnv.authenticate();
      tester.element(find.byType(LoginScreen)).read<SessionCubit>().markAuthenticated(SessionTarget.studio);
      await tester.pumpAndSettle();
      await tester.tap(avatar());
      await tester.pumpAndSettle();

      expect(inSheet(find.text('admin@example.com')), findsOneWidget);
      expect(tester.element(find.byType(ProfileSheet)).read<StudioIdentityCubit>().state, isA<StudioIdentityLoaded>());
    });

    testWidgets('a declined logout keeps the user signed in on the page', (tester) async {
      await pumpSignedIn(tester);

      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.widgetWithText(TextButton, 'No'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
    });
  });

  group('TopBarWidget - a failed /auth/me', () {
    testWidgets('shows the user as unknown with a retry, keeps the user signed in, and Retry asks Studio again', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      TestEnv.authenticate();
      final studio = _OnceRefusingStudio();
      await tester.pumpWidget(App(dependencies: _StudioIdentityDependencies(studio), language: 'en'));
      await tester.pumpAndSettle();

      await tester.tap(avatar());
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Unknown user')), findsOneWidget);
      expect(tester.element(find.byType(ProfileSheet)).read<SessionCubit>().state, isA<SessionAuthenticated>());
      expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);

      await tester.tap(inSheet(find.widgetWithText(TextButton, 'Retry')));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('admin@example.com')), findsOneWidget);
      expect(inSheet(find.text('Unknown user')), findsNothing);
      expect(studio.fetches, 2);
    });
  });

  group('TopBarWidget - sign-out progress', () {
    testWidgets('the signed-in shell sits under the sign-out progress barrier', (tester) async {
      await pumpSignedIn(tester);

      expect(
        find.ancestor(of: find.byType(TopBarWidget), matching: find.byType(SignOutProgressBarrier)),
        findsOneWidget,
      );
    });
  });

  group('TopBarWidget - Turkish', () {
    testWidgets('the profile sheet shows its entries and the role in Turkish', (tester) async {
      await pumpSignedIn(tester, language: 'tr');

      await tester.tap(avatar());
      await tester.pumpAndSettle();

      for (final label in ['Ayarlar', 'Çıkış Yap']) {
        expect(inSheet(find.widgetWithText(ListTile, label)), findsOneWidget, reason: label);
      }
      expect(inSheet(find.text('Yönetici')), findsOneWidget);
    });
  });

  group('TopBarWidget - phone width', () {
    // The narrowest phones, at the default text size and with the system text size raised to 130 percent, in both app
    // languages.
    for (final language in const ['en', 'tr']) {
      for (final textScale in const [1.0, 1.3]) {
        for (final size in const [Size(320, 568), Size(360, 640), Size(375, 667)]) {
          testWidgets('the signed-in top bar fits a ${size.width.toInt()}x${size.height.toInt()} phone at text scale '
              '$textScale in $language', (tester) async {
            await pumpSignedIn(tester, size: size, language: language, textScale: textScale);

            expect(tester.takeException(), isNull);
            expect(tester.getRect(avatar()).right, lessThanOrEqualTo(tester.getRect(find.byType(TopBarWidget)).right));
          });
        }
      }
    }

    // A screen reader user has to know what the bare avatar does, in the language of the app.
    for (final (language, label) in const [('en', 'Profile'), ('tr', 'Profil')]) {
      testWidgets('the avatar is announced as $label in $language', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSignedIn(tester, size: const Size(360, 640), language: language);

        expect(tester.getSemantics(avatar()), isSemantics(tooltip: label, isButton: true, hasTapAction: true));
        semantics.dispose();
      });
    }

    // A page title much longer than any of the app's, on the narrowest phone.
    testWidgets('a long page title is shortened instead of overflowing a 320 px bar', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      const title = 'A page title far longer than the narrowest phone has room for';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: TopBarWidget(title: title, onBack: () {}),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(avatar()).right, lessThanOrEqualTo(320));
      expect(find.text(title), findsOneWidget);
    });
  });
}

/// Studio's `GET /api/auth/me`, refusing the first request as Studio main does when it cannot check the token (a 401
/// without a code, which the ApiClient has already tried once more after a token refresh), then answering an admin.
class _OnceRefusingStudio implements IStudioIdentityRepository {
  int fetches = 0;

  @override
  Future<Result<StudioIdentity>> fetch() async {
    fetches++;
    if (fetches == 1) return const Failure(AuthError('The session answer is not signed in'));
    return const Success(StudioIdentity(username: 'admin@example.com', role: StudioAdminRole(), viaBearer: true));
  }

  @override
  Future<Result<void>> recordSignOut() async => const Success(null);
}

class _StudioIdentityDependencies extends LocalSignInDependencies {
  _StudioIdentityDependencies(this.studio);

  final IStudioIdentityRepository studio;

  @override
  IStudioIdentityRepository createStudioIdentityRepository(ApiClient apiClient) => studio;
}
