@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/change_password_page.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/widgets/unsaved_changes_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/test_env.dart';
import '../../support/user_menu.dart';

/// The app on the mock-backed development config, with the idle timeout production has.
const _app = App(
  language: 'en',
  dependencies: AppDependencies(
    appConfig: AppConfig(
      environment: Environment.dev,
      apiBaseUrl: null,
      certificatePins: <String>[],
      idleTimeout: Duration(minutes: 5),
    ),
  ),
);

/// Boots the app on a wide window, signed in when [signedIn].
Future<void> _pumpApp(WidgetTester tester, {bool signedIn = true}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1.0;
  if (signedIn) {
    TestEnv.authenticate();
  }
  await tester.pumpWidget(_app);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) => tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

/// What the Android back button does: the engine asks the framework to pop a route.
Future<void> _androidBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// The page in [page] holds the system back and the iOS back swipe, so they reach the route's onExit.
void _expectBackHeld(WidgetTester tester, Finder page) {
  expect(ModalRoute.of(tester.element(page))!.popDisposition, RoutePopDisposition.doNotPop);
}

Finder get _unsavedChangesDialog => find.text(S.current.unsaved_changes);

Future<void> _answer(WidgetTester tester, {required bool leave}) async {
  await tester.tap(find.text(leave ? S.current.yes : S.current.no));
  await tester.pumpAndSettle();
}

/// Opens the change password page from the settings, as its tile does, and types in it.
Future<void> _openDirtyChangePasswordForm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(settingsChangePasswordButtonKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(changePasswordTextFieldCurrentPasswordKey), 'secret');
  await tester.pumpAndSettle();
  expect(find.byType(ChangePasswordScreen), findsOneWidget);
}

void main() {
  group('A dirty change password form', () {
    testWidgets('asks before the Android back button pops it off the settings page', (tester) async {
      await _pumpApp(tester);
      await _openDirtyChangePasswordForm(tester);
      _expectBackHeld(tester, find.byType(ChangePasswordScreen));

      await _androidBack(tester);
      expect(_unsavedChangesDialog, findsOneWidget);

      await _answer(tester, leave: true);
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('asks before the bottom navigation bar leaves it, and stays when the user stays', (tester) async {
      await _pumpApp(tester);
      await _openDirtyChangePasswordForm(tester);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Connections'));
      await tester.pumpAndSettle();
      expect(_unsavedChangesDialog, findsOneWidget);

      await _answer(tester, leave: false);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Connections'));
      await tester.pumpAndSettle();
      await _answer(tester, leave: true);
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(_router(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
    });

    testWidgets('does not hold up signing out', (tester) async {
      await _pumpApp(tester);
      await _openDirtyChangePasswordForm(tester);

      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.text(S.current.yes));
      await tester.pumpAndSettle();

      expect(_unsavedChangesDialog, findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('does not hold up a session the server ends', (tester) async {
      await _pumpApp(tester);
      await _openDirtyChangePasswordForm(tester);

      await tester
          .element(find.byType(ChangePasswordScreen))
          .read<SessionCubit>()
          .endSession(reason: SessionExpiredReason.expired);
      await tester.pumpAndSettle();

      expect(_unsavedChangesDialog, findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('gives way to an idle timeout while the unsaved-changes dialog is open', (tester) async {
      await _pumpApp(tester);
      await _openDirtyChangePasswordForm(tester);
      await _androidBack(tester);
      expect(_unsavedChangesDialog, findsOneWidget);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(_unsavedChangesDialog, findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ResponsiveScaffold), findsNothing);
    });
  });

  group('A dirty register form', () {
    testWidgets('asks before the Android back button returns to the login page', (tester) async {
      await _pumpApp(tester, signedIn: false);
      await tester.tap(find.byKey(loginButtonRegisterKey));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      await tester.enterText(find.byKey(const Key('userEditorFirstNameFieldKey')), 'New');
      await tester.pumpAndSettle();

      _expectBackHeld(tester, find.byType(RegisterScreen));

      await _androidBack(tester);
      expect(_unsavedChangesDialog, findsOneWidget);

      await _answer(tester, leave: false);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('holds the iOS back swipe', (tester) async {
      await _pumpApp(tester, signedIn: false);
      await tester.tap(find.byKey(loginButtonRegisterKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('userEditorFirstNameFieldKey')), 'New');
      await tester.pumpAndSettle();

      await tester.timedDragFrom(const Offset(5, 400), const Offset(1200, 0), const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(tester.getTopLeft(find.byType(RegisterScreen)).dx, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('A dirty forgot password form', () {
    testWidgets('asks before the Android back button returns to the login page', (tester) async {
      await _pumpApp(tester, signedIn: false);
      await tester.tap(find.byKey(loginButtonForgotPasswordKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(forgotPasswordTextFieldEmailKey), 'someone@example.com');
      await tester.pumpAndSettle();
      _expectBackHeld(tester, find.byType(ForgotPasswordScreen));

      await _androidBack(tester);
      expect(_unsavedChangesDialog, findsOneWidget);

      await _answer(tester, leave: true);
      expect(find.byType(ForgotPasswordScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  testWidgets('every route of a page with an unsaved-changes scope asks before it is left', (tester) async {
    await _pumpApp(tester);
    final routes = <String, GoRoute>{};
    void collect(List<RouteBase> list) {
      for (final route in list) {
        if (route is GoRoute) routes[route.path] = route;
        collect(route.routes);
      }
    }

    collect(_router(tester).configuration.routes);
    for (final path in [
      ApplicationRoutesConstants.changePassword,
      ApplicationRoutesConstants.forgotPassword,
      ApplicationRoutesConstants.register,
    ]) {
      expect(routes[path]?.onExit, confirmLeavingUnsavedChanges, reason: path);
    }
  });
}
