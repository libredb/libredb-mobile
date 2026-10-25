@Tags(['widget'])
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/lock/app_lock_gate.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/core/security/screen_capture_guard.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';

import '../../mocks/mock_classes.dart';
import '../../support/screen_capture.dart';

class _MockSessionCubit extends MockCubit<SessionState> implements SessionCubit {}

class _MockSignOutBloc extends MockBloc<SignOutEvent, SignOutState> implements SignOutBloc {}

const _on5 = AppLockSettings(enabled: true, timeout: AppLockTimeout.fiveMinutes);

void main() {
  late MockAppLockBloc lock;
  late StreamController<AppLockState> lockStates;
  late _MockSessionCubit session;
  late _MockSignOutBloc signOut;
  late ScreenCaptureProtection capture;

  setUp(() {
    lock = MockAppLockBloc();
    lockStates = StreamController<AppLockState>.broadcast();
    session = _MockSessionCubit();
    signOut = _MockSignOutBloc();
    capture = recordingScreenCaptureProtection();
    whenListen(
      session,
      const Stream<SessionState>.empty(),
      initialState: const SessionAuthenticated(target: SessionTarget.studio),
    );
    whenListen(signOut, const Stream<SignOutState>.empty(), initialState: const SignOutInitial());
  });

  tearDown(() => lockStates.close());

  Future<void> pump(WidgetTester tester, AppLockState initial) async {
    whenListen(lock, lockStates.stream, initialState: initial);
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Login page')),
        ),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
          routes: [
            GoRoute(
              path: 'editor',
              builder: (_, _) => const Scaffold(
                body: Column(
                  children: [
                    TextField(key: Key('editor')),
                    ScreenCaptureGuard(child: Text('A shown result')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      withScreenCaptureProtection(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppLockBloc>.value(value: lock),
            BlocProvider<SessionCubit>.value(value: session),
            BlocProvider<SignOutBloc>.value(value: signOut),
          ],
          child: MaterialApp.router(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            locale: const Locale('en'),
            routerConfig: router,
            builder: (context, child) => AppLockGate(router: router, child: child!),
          ),
        ),
        protection: capture,
      ),
    );
    // Not pumpAndSettle: the spinner of a starting lock never settles.
    await tester.pump();
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, AppLockState state) async {
    lockStates.add(state);
    await tester.pumpAndSettle();
  }

  testWidgets('the lock covers the page and the page keeps its text and result once it opens', (tester) async {
    await pump(tester, const AppLockUnlocked(settings: _on5));
    await tester.enterText(find.byKey(const Key('editor')), 'SELECT 1');
    expect(capture.leases, 1);

    await emit(tester, const AppLockLocked(settings: _on5));
    expect(find.byKey(appLockScreenKey), findsOneWidget);
    expect(find.text('SELECT 1'), findsNothing);
    expect(find.text('A shown result'), findsNothing);
    // Offstage: the guard under the lock gives its lease back, so the lock screen can be captured.
    expect(capture.leases, 0);

    await emit(tester, const AppLockUnlocked(settings: _on5));
    expect(find.byKey(appLockScreenKey), findsNothing);
    expect(find.text('SELECT 1'), findsOneWidget);
    expect(find.text('A shown result'), findsOneWidget);
    expect(capture.leases, 1);
  });

  testWidgets('the system back does nothing while locked, and pops the page once open', (tester) async {
    await pump(tester, const AppLockLocked(settings: _on5));

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    await emit(tester, const AppLockUnlocked(settings: _on5));
    expect(find.byKey(const Key('editor')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a screen reader reads only the lock screen', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const AppLockLocked(settings: _on5));

    expect(find.bySemanticsLabel('LibreDB is locked'), findsOneWidget);
    final labels = <String>[];
    void visit(SemanticsNode node) {
      if (node.label.isNotEmpty) labels.add(node.label);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(labels, isNot(contains('A shown result')));
    semantics.dispose();
  });

  testWidgets('while the settings are read after a restore, a spinner covers the pages', (tester) async {
    await pump(tester, const AppLockStarting());

    expect(find.byKey(appLockRestoreKey), findsOneWidget);
    expect(find.byKey(const Key('editor')), findsNothing);

    await emit(tester, const AppLockOff(settings: AppLockSettings.defaults));
    expect(find.byKey(appLockRestoreKey), findsNothing);
    expect(find.byKey(const Key('editor')), findsOneWidget);
  });

  testWidgets('keyboard input after locking does not reach the hidden editor', (tester) async {
    await pump(tester, const AppLockUnlocked(settings: _on5));
    await tester.enterText(find.byKey(const Key('editor')), 'SELECT 1');
    expect(tester.testTextInput.hasAnyClients, isTrue);

    await emit(tester, const AppLockLocked(settings: _on5));
    if (tester.testTextInput.hasAnyClients) {
      tester.testTextInput.enterText('DROP TABLE t');
      await tester.pump();
    }

    expect(tester.testTextInput.hasAnyClients, isFalse);
    final editor = find.descendant(
      of: find.byKey(const Key('editor'), skipOffstage: false),
      matching: find.byType(EditableText, skipOffstage: false),
    );
    expect(tester.widget<EditableText>(editor).controller.text, 'SELECT 1');
  });

  testWidgets('while the idle sign-out ends the session the pages stay hidden, without the lock screen', (
    tester,
  ) async {
    await pump(tester, const AppLockUnlocked(settings: _on5));

    lockStates.add(const AppLockIdleSigningOut(settings: _on5));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(appLockRestoreKey), findsOneWidget);
    expect(find.byKey(appLockScreenKey), findsNothing);
    expect(find.byKey(const Key('editor')), findsNothing);
    expect(await tester.binding.handlePopRoute(), isTrue);
  });

  testWidgets('while a required lock checks the device after a sign-in the pages stay hidden', (tester) async {
    await pump(tester, const AppLockChecking(settings: _on5));

    expect(find.byKey(appLockRestoreKey), findsOneWidget);
    expect(find.byKey(appLockScreenKey), findsNothing);
    expect(find.byKey(const Key('editor')), findsNothing);
  });

  testWidgets('Sign out keeps the pages hidden until the login page shows', (tester) async {
    final signOutStates = StreamController<SignOutState>.broadcast();
    addTearDown(signOutStates.close);
    whenListen(signOut, signOutStates.stream, initialState: const SignOutInitial());
    await pump(tester, const AppLockLocked(settings: _on5));

    await tester.tap(find.byKey(appLockSignOutKey));
    await tester.pump();
    // The session ended, so the lock opens, before the sign-out has sent the router to the login page.
    lockStates.add(const AppLockUnlocked(settings: _on5));
    await tester.pump();
    expect(find.byKey(const Key('editor')), findsNothing);
    expect(find.byKey(appLockRestoreKey), findsOneWidget);

    signOutStates.add(const SignedOut());
    await tester.pump();
    await tester.pump();
    expect(find.text('Login page'), findsOneWidget);
    expect(find.byKey(appLockRestoreKey), findsNothing);
  });

  testWidgets('while signed out the starting lock covers nothing', (tester) async {
    whenListen(session, const Stream<SessionState>.empty(), initialState: const SessionUnauthenticated());
    await pump(tester, const AppLockStarting());

    expect(find.byKey(appLockRestoreKey), findsNothing);
    expect(find.byKey(const Key('editor')), findsOneWidget);
  });
}
