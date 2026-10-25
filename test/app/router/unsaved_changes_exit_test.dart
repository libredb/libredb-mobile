@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/connections/navigation/connections_routes.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/widgets/unsaved_changes_guard.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/test_env.dart';
import '../../support/user_menu.dart';

class _MockSessionCubit extends Mock implements SessionCubit {}

class _MockGoRouterState extends Mock implements GoRouterState {}

/// No page of the app holds a form with unsaved changes yet, so these tests add one to the Connections tab of the
/// shell: a page guarded the way a form page is, behind the real [AppRouterFactory] and the registry that [App] wires
/// to it.
const _formPath = '${ApplicationRoutesConstants.connectionList}/unsaved-changes-test-form';

const _formFieldKey = Key('unsavedChangesTestField');

class _FormPage extends StatefulWidget {
  const _FormPage();

  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesScope(
      hasUnsavedChanges: () => _formKey.currentState?.isDirty ?? false,
      onBack: () => context.pop(),
      child: Builder(
        builder: (context) => FormBuilder(
          key: _formKey,
          onChanged: () => UnsavedChangesScope.formChanged(context),
          child: FormBuilderTextField(key: _formFieldKey, name: 'name'),
        ),
      ),
    );
  }
}

final _formRoute = GoRoute(
  path: _formPath,
  onExit: confirmLeavingUnsavedChanges,
  pageBuilder: (context, state) => MaterialPage(key: state.pageKey, child: const _FormPage()),
);

/// The app on the mock-backed development config, with the idle timeout production has.
final _app = App(
  language: 'en',
  dependencies: LocalSignInDependencies(
    appConfig: const AppConfig(
      environment: Environment.dev,
      apiBaseUrl: null,
      certificatePins: <String>[],
      idleTimeout: Duration(minutes: 5),
    ),
  ),
);

/// Boots the signed-in app on a wide window with the test form among the shell's routes.
Future<void> _pumpApp(WidgetTester tester) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1.0;
  ConnectionsFeatureRoutes.routes.add(_formRoute);
  addTearDown(() => ConnectionsFeatureRoutes.routes.remove(_formRoute));
  TestEnv.authenticate();
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

Finder get _unsavedChangesDialog => find.text(S.current.unsaved_changes);

Future<void> _answer(WidgetTester tester, {required bool leave}) async {
  await tester.tap(find.text(leave ? S.current.yes : S.current.no));
  await tester.pumpAndSettle();
}

/// Pushes the test form on the connection list and types in it.
Future<void> _openDirtyForm(WidgetTester tester) async {
  expect(find.byType(ConnectionListPage), findsOneWidget);
  _router(tester).push(_formPath);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(_formFieldKey), 'changed');
  await tester.pumpAndSettle();
  expect(find.byType(_FormPage), findsOneWidget);
  expect(ModalRoute.of(tester.element(find.byType(_FormPage)))!.popDisposition, RoutePopDisposition.doNotPop);
}

void main() {
  group('AppRouterFactory.isExitForced', () {
    late _MockSessionCubit sessionCubit;
    late AppRouterFactory factory;

    GoRouterState leaving(String location) {
      final state = _MockGoRouterState();
      when(() => state.matchedLocation).thenReturn(location);
      return state;
    }

    setUp(() {
      sessionCubit = _MockSessionCubit();
      factory = AppRouterFactory(sessionCubit: sessionCubit);
    });

    test('lets a page ask while the session is authenticated', () {
      when(() => sessionCubit.state).thenReturn(const SessionAuthenticated(target: SessionTarget.studio));

      expect(factory.isExitForced(leaving(ApplicationRoutesConstants.settings)), isFalse);
    });

    test('forces a page that needs a session to close once the session has ended', () {
      when(() => sessionCubit.state).thenReturn(const SessionUnauthenticated(reason: SessionExpiredReason.expired));

      expect(factory.isExitForced(leaving(ApplicationRoutesConstants.settings)), isTrue);
    });

    test('forces a page that needs a session to close while the session is unknown', () {
      when(() => sessionCubit.state).thenReturn(const SessionUnknown());

      expect(factory.isExitForced(leaving(_formPath)), isTrue);
    });

    test('lets the login page ask without a session', () {
      when(() => sessionCubit.state).thenReturn(const SessionUnauthenticated());

      expect(factory.isExitForced(leaving(ApplicationRoutesConstants.login)), isFalse);
    });
  });

  group('A dirty form in the app', () {
    testWidgets('asks before the Android back button pops it off the connection list', (tester) async {
      await _pumpApp(tester);
      await _openDirtyForm(tester);

      await _androidBack(tester);
      expect(_unsavedChangesDialog, findsOneWidget);

      await _answer(tester, leave: true);
      expect(find.byType(_FormPage), findsNothing);
      expect(find.byType(ConnectionListPage), findsOneWidget);
    });

    testWidgets('asks before the bottom navigation bar leaves it, and stays when the user stays', (tester) async {
      await _pumpApp(tester);
      await _openDirtyForm(tester);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Browse'));
      await tester.pumpAndSettle();
      expect(_unsavedChangesDialog, findsOneWidget);

      await _answer(tester, leave: false);
      expect(find.byType(_FormPage), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Browse'));
      await tester.pumpAndSettle();
      await _answer(tester, leave: true);
      expect(find.byType(_FormPage), findsNothing);
      expect(_router(tester).state.uri.path, ApplicationRoutesConstants.browse);
    });

    testWidgets('does not hold up signing out', (tester) async {
      await _pumpApp(tester);
      await _openDirtyForm(tester);

      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.text(S.current.yes));
      await tester.pumpAndSettle();

      expect(_unsavedChangesDialog, findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('does not hold up a session the server ends', (tester) async {
      await _pumpApp(tester);
      await _openDirtyForm(tester);

      await tester
          .element(find.byType(_FormPage))
          .read<SessionCubit>()
          .endSession(reason: SessionExpiredReason.expired);
      await tester.pumpAndSettle();

      expect(_unsavedChangesDialog, findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('gives way to an idle timeout while the unsaved-changes dialog is open', (tester) async {
      await _pumpApp(tester);
      await _openDirtyForm(tester);
      await _androidBack(tester);
      expect(_unsavedChangesDialog, findsOneWidget);

      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();

      expect(_unsavedChangesDialog, findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ResponsiveScaffold), findsNothing);
    });
  });
}
