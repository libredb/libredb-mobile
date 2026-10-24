@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/recents_preview.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_sign_out_auth_repository.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';
import '../../support/test_env.dart';

/// The mock-backed app with the device's authentication and the preview switch as doubles.
class _LockDependencies extends LocalSignInDependencies {
  _LockDependencies(this.authenticator, {super.appConfig});

  final IDeviceAuthenticator authenticator;
  final hidden = <bool>[];

  @override
  IDeviceAuthenticator createDeviceAuthenticator() => authenticator;

  @override
  IRecentsPreview createRecentsPreview() => _RecordingRecentsPreview(hidden);
}

class _RecordingRecentsPreview implements IRecentsPreview {
  _RecordingRecentsPreview(this.calls);

  final List<bool> calls;

  @override
  Future<bool> setHidden(bool hidden) async {
    calls.add(hidden);
    return true;
  }
}

/// The idle timeout of production, which the app lock's idle rule reads.
const _config = AppConfig(
  environment: Environment.dev,
  apiBaseUrl: null,
  certificatePins: <String>[],
  idleTimeout: Duration(minutes: 15),
);

Future<void> _turnLockOn() async {
  await AppLocalStorage().save(StorageKeys.appLockEnabled.key, true);
  await AppLocalStorage().save(StorageKeys.appLockTimeout.key, 'fiveMinutes');
}

/// Every label the semantics tree reads out now.
List<String> _semanticLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return labels;
}

Future<void> _leaveFor(WidgetTester tester, Duration away) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  await tester.pump(away);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

/// Lets the mock answer the requests the pages under the lock sent: their spinners are stopped while covered, so
/// `pumpAndSettle` returns before the mock's latency has passed.
Future<void> _answerPendingRequests(WidgetTester tester) => tester.pump(const Duration(seconds: 1));

void main() {
  late MockIDeviceAuthenticator authenticator;

  setUpAll(() => registerFallbackValue(const DeviceAuthPrompt(reason: '', title: '', cancel: '')));

  setUp(() {
    authenticator = MockIDeviceAuthenticator();
    when(() => authenticator.canAuthenticate()).thenAnswer((_) async => true);
    when(() => authenticator.authenticate(any())).thenAnswer((_) async => const DeviceAuthSucceeded());
  });

  Widget app({AppConfig config = _config}) => App(
    language: 'en',
    dependencies: _LockDependencies(authenticator, appConfig: config),
  );

  testWidgets('a cold start that restores a session shows only the lock screen, and Unlock opens the app', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _turnLockOn();
    TestEnv.authenticate();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(appLockScreenKey), findsOneWidget);
    expect(find.byType(ResponsiveScaffold), findsNothing, reason: 'the pages stay mounted offstage, unseen');
    expect(find.byType(ResponsiveScaffold, skipOffstage: false), findsOneWidget);
    final labels = _semanticLabels(tester);
    expect(labels, contains('LibreDB is locked'));
    expect(labels.where((label) => label.contains('Connections')), isEmpty);

    await tester.tap(find.byKey(appLockUnlockKey));
    await tester.pumpAndSettle();

    expect(find.byKey(appLockScreenKey), findsNothing);
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the system back does nothing while locked', (tester) async {
    await _turnLockOn();
    TestEnv.authenticate();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byKey(appLockScreenKey), findsOneWidget);
    await _answerPendingRequests(tester);
  });

  testWidgets('Sign out from the lock screen reaches the login page', (tester) async {
    await _turnLockOn();
    TestEnv.authenticate();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(appLockSignOutKey));
    await tester.pumpAndSettle();
    await tester.pump(SsoSignOutAuthRepository.defaultStudioSignOutTimeout);
    await tester.pumpAndSettle();

    expect(find.byKey(appLockScreenKey), findsNothing);
    expect(find.byKey(loginButtonSsoKey), findsOneWidget);
    verifyNever(() => authenticator.authenticate(any()));
  });

  testWidgets('a sign-in at the identity provider opens the app without the lock', (tester) async {
    await _turnLockOn();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(appLockScreenKey), findsNothing);

    await tester.tap(find.byKey(loginButtonSsoKey));
    await tester.pumpAndSettle();

    expect(find.byKey(appLockScreenKey), findsNothing);
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
  });

  testWidgets('back after six minutes asks, back after one minute does not', (tester) async {
    await _turnLockOn();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(loginButtonSsoKey));
    await tester.pumpAndSettle();

    await _leaveFor(tester, const Duration(minutes: 1));
    expect(find.byKey(appLockScreenKey), findsNothing);

    await _leaveFor(tester, const Duration(minutes: 6));
    expect(find.byKey(appLockScreenKey), findsOneWidget);
    await _answerPendingRequests(tester);
  });

  testWidgets('resuming after the idle period signs out and shows no lock', (tester) async {
    await _turnLockOn();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(loginButtonSsoKey));
    await tester.pumpAndSettle();

    await _leaveFor(tester, const Duration(minutes: 16));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byKey(appLockScreenKey), findsNothing);
    expect(find.byKey(loginButtonSsoKey), findsOneWidget);
  });

  testWidgets('a build that requires the lock on a device without a screen lock offers only Sign out', (tester) async {
    when(() => authenticator.canAuthenticate()).thenAnswer((_) async => false);
    TestEnv.authenticate();
    await tester.pumpWidget(
      app(
        config: const AppConfig(
          environment: Environment.dev,
          apiBaseUrl: null,
          certificatePins: <String>[],
          idleTimeout: null,
          appLockRequired: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(appLockScreenKey), findsOneWidget);
    expect(find.byKey(appLockUnlockKey), findsNothing);
    expect(find.text('Set a screen lock on this device to use LibreDB, or sign out.'), findsOneWidget);
    expect(find.byKey(appLockSignOutKey), findsOneWidget);
    await _answerPendingRequests(tester);
  });

  testWidgets('the lock off by default changes nothing', (tester) async {
    TestEnv.authenticate();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(appLockScreenKey), findsNothing);
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
    verifyNever(() => authenticator.canAuthenticate());
  });
}
