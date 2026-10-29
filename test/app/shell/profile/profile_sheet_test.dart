@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/session_target_switch_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockStudioIdentityCubit identity;
  late MockConnectionPolicyCubit policy;
  late MockPlatformIdentityCubit platformIdentity;
  late MockSessionTargetSwitchBloc switchBloc;

  const admin = StudioIdentity(username: 'admin@example.com', role: StudioAdminRole());
  const user = StudioIdentity(username: 'user@example.com', role: StudioUserRole());
  const governed = ConnectionPolicy(customConnections: false, governance: true);
  const ungoverned = ConnectionPolicy(customConnections: true, governance: false);

  setUp(() {
    identity = MockStudioIdentityCubit();
    policy = MockConnectionPolicyCubit();
    platformIdentity = MockPlatformIdentityCubit();
    switchBloc = MockSessionTargetSwitchBloc();
    when(() => platformIdentity.load()).thenAnswer((_) async {});
    when(() => identity.load()).thenAnswer((_) async {});
    when(() => policy.load()).thenAnswer((_) async {});
  });

  // A page with one button that opens the sheet, as the top bar does, keeping what the sheet answered.
  Future<List<ProfileSheetAction?>> pumpSheet(
    WidgetTester tester, {
    required StudioIdentityState identityState,
    ConnectionPolicyState policyState = const ConnectionPolicyLoaded(ungoverned),
    String language = 'en',
    SessionTarget target = SessionTarget.studio,
    PlatformIdentityState platformState = const PlatformIdentityInitial(),
    AppConfig appConfig = const AppConfig.test(),
    SessionTargetSwitchState switchState = const SessionTargetSwitchIdle(),
  }) async {
    when(() => switchBloc.state).thenReturn(switchState);
    when(() => identity.state).thenReturn(identityState);
    when(() => platformIdentity.state).thenReturn(platformState);
    when(() => policy.state).thenReturn(policyState);
    final answers = <ProfileSheetAction?>[];
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          RepositoryProvider<AppConfig>.value(value: appConfig),
          BlocProvider<SessionTargetSwitchBloc>.value(value: switchBloc),
          BlocProvider<StudioIdentityCubit>.value(value: identity),
          BlocProvider<ConnectionPolicyCubit>.value(value: policy),
          BlocProvider<PlatformIdentityCubit>.value(value: platformIdentity),
        ],
        child: MaterialApp(
          locale: Locale(language),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => answers.add(await ProfileSheet.show(context, target: target)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // A spinner runs while Studio has not answered, so the sheet's opening is pumped for its length, never settled.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return answers;
  }

  Finder inSheet(Finder finder) => find.descendant(of: find.byType(ProfileSheet), matching: finder);

  group('ProfileSheet - who is signed in', () {
    testWidgets("shows an admin's username and the role Administrator", (tester) async {
      await pumpSheet(tester, identityState: const StudioIdentityLoaded(admin));

      expect(inSheet(find.text('admin@example.com')), findsOneWidget);
      expect(inSheet(find.text('Administrator')), findsOneWidget);
      expect(inSheet(find.text('User')), findsNothing);
    });

    testWidgets("shows a user's username and the role User", (tester) async {
      await pumpSheet(tester, identityState: const StudioIdentityLoaded(user));

      expect(inSheet(find.text('user@example.com')), findsOneWidget);
      expect(inSheet(find.text('User')), findsOneWidget);
      expect(inSheet(find.text('Administrator')), findsNothing);
    });

    testWidgets('shows a role this app does not know exactly as Studio sent it', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(
          StudioIdentity(username: 'a@example.com', role: StudioUnknownRole('auditor')),
        ),
      );

      expect(inSheet(find.text('auditor')), findsOneWidget);
      expect(inSheet(find.text('Administrator')), findsNothing);
      expect(inSheet(find.text('User')), findsNothing);
    });

    testWidgets('shows the roles in Turkish', (tester) async {
      await pumpSheet(tester, identityState: const StudioIdentityLoaded(admin), language: 'tr');

      expect(inSheet(find.text('Yönetici')), findsOneWidget);
    });

    testWidgets('shows a progress indicator while Studio has not answered', (tester) async {
      await pumpSheet(tester, identityState: const StudioIdentityLoading());

      expect(inSheet(find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(inSheet(find.text('Unknown user')), findsNothing);
    });

    testWidgets('a failed answer shows the username as unknown, the reason and a retry that asks Studio again', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityFailure(AppErrorCode.studioIdentityProviderUnavailable),
      );

      expect(inSheet(find.text('Unknown user')), findsOneWidget);
      expect(inSheet(find.text(S.current.error_studio_identity_provider_unavailable)), findsOneWidget);

      await tester.tap(inSheet(find.widgetWithText(TextButton, 'Retry')));
      await tester.pump();

      verify(() => identity.load()).called(1);
    });
  });

  group('ProfileSheet - mode', () {
    testWidgets('a Studio session shows the mode Studio with the Studio identity', (tester) async {
      await pumpSheet(tester, identityState: const StudioIdentityLoaded(admin));

      expect(inSheet(find.text('Studio')), findsOneWidget);
      expect(inSheet(find.text('Platform admin')), findsNothing);
      expect(inSheet(find.text('admin@example.com')), findsOneWidget);
    });

    const platformAdmin = PlatformIdentity(
      id: 'cm0platformadmin0000000001',
      email: 'platform.admin@example.org',
      name: 'Platform Admin',
      roles: ['PLATFORM_ADMIN'],
      permissions: [],
      tenant: PlatformTenant(id: 't', name: 'Example Org', slug: 'example-org'),
    );

    testWidgets('a Platform session shows Platform admin, the name and the tenant, and nothing of Studio', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(admin),
        policyState: const ConnectionPolicyFailure(AppErrorCode.generic),
        target: SessionTarget.platform,
        platformState: const PlatformIdentityLoaded(platformAdmin),
      );

      expect(inSheet(find.text('Platform admin')), findsOneWidget);
      expect(inSheet(find.text('Platform Admin')), findsOneWidget);
      expect(inSheet(find.text('Example Org')), findsOneWidget);
      expect(inSheet(find.text('admin@example.com')), findsNothing);
      expect(inSheet(find.byType(Chip)), findsNothing);
      expect(inSheet(find.widgetWithText(ListTile, 'Settings')), findsOneWidget);
      expect(inSheet(find.widgetWithText(ListTile, 'Logout')), findsOneWidget);
      verifyNever(() => policy.load());
    });

    testWidgets('a Platform session shows the email when Platform has no name', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityInitial(),
        target: SessionTarget.platform,
        platformState: const PlatformIdentityLoaded(
          PlatformIdentity(
            id: 'id',
            email: 'platform.admin@example.org',
            roles: [],
            permissions: [],
            tenant: PlatformTenant(id: 't', name: 'Example Org', slug: 'example-org'),
          ),
        ),
      );

      expect(inSheet(find.text('platform.admin@example.org')), findsOneWidget);
    });

    testWidgets('a Platform session shows the mode in Turkish', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityInitial(),
        target: SessionTarget.platform,
        platformState: const PlatformIdentityLoaded(platformAdmin),
        language: 'tr',
      );

      expect(inSheet(find.text('Platform yöneticisi')), findsOneWidget);
    });

    testWidgets('a Platform identity that failed shows the reason and a Retry that asks Platform again', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityInitial(),
        target: SessionTarget.platform,
        platformState: const PlatformIdentityFailure(AppErrorCode.platformInternalError),
      );

      await tester.tap(inSheet(find.widgetWithText(TextButton, 'Retry')));
      await tester.pump();

      verify(() => platformIdentity.load()).called(1);
      verifyNever(() => identity.load());
    });

    testWidgets('a Platform identity still loading shows a progress indicator', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityInitial(),
        target: SessionTarget.platform,
        platformState: const PlatformIdentityLoading(),
      );

      expect(inSheet(find.byType(CircularProgressIndicator)), findsOneWidget);
    });
  });

  group('ProfileSheet - governance chip', () {
    testWidgets('shows Governed by LibreDB Platform when the policy says governance', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(user),
        policyState: const ConnectionPolicyLoaded(governed),
      );

      expect(inSheet(find.widgetWithText(Chip, 'Governed by LibreDB Platform')), findsOneWidget);
    });

    for (final (shape, state) in <(String, ConnectionPolicyState)>[
      ('a policy without governance', const ConnectionPolicyLoaded(ungoverned)),
      ('no policy yet', const ConnectionPolicyInitial()),
      ('a policy still loading', const ConnectionPolicyLoading()),
      ('a failed policy request', const ConnectionPolicyFailure(AppErrorCode.generic)),
    ]) {
      testWidgets('shows no chip for $shape', (tester) async {
        await pumpSheet(tester, identityState: const StudioIdentityLoaded(user), policyState: state);

        expect(inSheet(find.byType(Chip)), findsNothing);
        expect(find.text('Governed by LibreDB Platform'), findsNothing);
      });
    }

    testWidgets('opening the sheet after a failed policy request asks Studio for the policy again', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(user),
        policyState: const ConnectionPolicyFailure(AppErrorCode.generic),
      );

      verify(() => policy.load()).called(1);
    });

    for (final (shape, state) in <(String, ConnectionPolicyState)>[
      ('a loaded policy', const ConnectionPolicyLoaded(governed)),
      ('no policy yet', const ConnectionPolicyInitial()),
      ('a policy still loading', const ConnectionPolicyLoading()),
    ]) {
      testWidgets('opening the sheet with $shape does not ask Studio for the policy', (tester) async {
        await pumpSheet(tester, identityState: const StudioIdentityLoaded(user), policyState: state);

        verifyNever(() => policy.load());
      });
    }
  });

  group('ProfileSheet - entries', () {
    testWidgets('Settings closes the sheet and answers settings', (tester) async {
      final answers = await pumpSheet(tester, identityState: const StudioIdentityLoaded(admin));

      await tester.tap(inSheet(find.widgetWithText(ListTile, 'Settings')));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileSheet), findsNothing);
      expect(answers, [ProfileSheetAction.settings]);
    });

    testWidgets('Logout closes the sheet and answers signOut', (tester) async {
      final answers = await pumpSheet(tester, identityState: const StudioIdentityLoaded(admin));

      await tester.tap(inSheet(find.widgetWithText(ListTile, 'Logout')));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileSheet), findsNothing);
      expect(answers, [ProfileSheetAction.signOut]);
    });

    for (final state in const <StudioIdentityState>[
      StudioIdentityLoading(),
      StudioIdentityFailure(AppErrorCode.generic),
    ]) {
      testWidgets('both entries are there for ${state.runtimeType}', (tester) async {
        await pumpSheet(tester, identityState: state);

        expect(inSheet(find.widgetWithText(ListTile, 'Settings')), findsOneWidget);
        expect(inSheet(find.widgetWithText(ListTile, 'Logout')), findsOneWidget);
      });
    }

    testWidgets('a Studio session in a build with Platform offers Switch to Platform above Settings', (tester) async {
      final answers = await pumpSheet(tester, identityState: const StudioIdentityLoaded(admin));

      final tile = inSheet(find.byKey(profileSwitchModeKey));
      expect(find.descendant(of: tile, matching: find.text('Switch to Platform')), findsOneWidget);
      expect(
        tester.getTopLeft(tile).dy,
        lessThan(tester.getTopLeft(inSheet(find.widgetWithText(ListTile, 'Settings'))).dy),
      );

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileSheet), findsNothing);
      expect(answers, [ProfileSheetAction.switchMode]);
    });

    testWidgets('a Platform session offers Switch to Studio', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityInitial(),
        target: SessionTarget.platform,
        platformState: const PlatformIdentityLoading(),
      );

      expect(
        find.descendant(of: inSheet(find.byKey(profileSwitchModeKey)), matching: find.text('Switch to Studio')),
        findsOneWidget,
      );
    });

    testWidgets('a build without a Platform target offers no switch', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(admin),
        appConfig: const AppConfig(
          environment: Environment.mock,
          apiBaseUrl: null,
          certificatePins: <String>[],
          idleTimeout: null,
        ),
      );

      expect(inSheet(find.byKey(profileSwitchModeKey)), findsNothing);
      expect(inSheet(find.text('Switch to Platform')), findsNothing);
    });

    testWidgets('while a switch runs the tile shows progress and a tap sends nothing', (tester) async {
      final answers = await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(admin),
        switchState: const SessionTargetSwitchInProgress(SessionTarget.platform),
      );

      final tile = inSheet(find.byKey(profileSwitchModeKey));
      expect(find.descendant(of: tile, matching: find.byType(CircularProgressIndicator)), findsOneWidget);

      await tester.tap(tile);
      await tester.pump();

      expect(find.byType(ProfileSheet), findsOneWidget);
      expect(answers, isEmpty);
    });

    testWidgets('the switch reads Turkish', (tester) async {
      await pumpSheet(tester, identityState: const StudioIdentityLoaded(admin), language: 'tr');

      expect(inSheet(find.text("Platform'a geç")), findsOneWidget);
    });

    testWidgets('fits a 320 px phone at text scale 1.3 in Turkish', (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;

      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(
          StudioIdentity(
            username: 'a.very.long.username.of.someone@a-long-company-domain.example.com',
            role: StudioAdminRole(),
          ),
        ),
        policyState: const ConnectionPolicyLoaded(governed),
        language: 'tr',
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('ProfileSheet - access requests', () {
    for (final (platform, governance) in [(true, true), (true, false), (false, true), (false, false)]) {
      final shown = platform && governance;
      testWidgets('a Studio session ${shown ? 'offers' : 'offers no'} Access requests '
          'with ${platform ? 'a' : 'no'} Platform target and governance ${governance ? 'on' : 'off'}', (tester) async {
        await pumpSheet(
          tester,
          identityState: const StudioIdentityLoaded(user),
          policyState: ConnectionPolicyLoaded(governance ? governed : ungoverned),
          appConfig: platform ? const AppConfig.test() : const AppConfig.local(),
        );

        expect(inSheet(find.byKey(profileAccessRequestsKey)), shown ? findsOneWidget : findsNothing);
        expect(inSheet(find.text('Access requests')), shown ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('a policy that is not loaded offers no Access requests', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(user),
        policyState: const ConnectionPolicyLoading(),
      );

      expect(inSheet(find.byKey(profileAccessRequestsKey)), findsNothing);
    });

    testWidgets('a Platform session never offers Access requests', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityInitial(),
        target: SessionTarget.platform,
        policyState: const ConnectionPolicyLoaded(governed),
      );

      expect(inSheet(find.byKey(profileAccessRequestsKey)), findsNothing);
    });

    testWidgets('the tile sits directly under the mode switch', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(user),
        policyState: const ConnectionPolicyLoaded(governed),
      );

      final switchTop = tester.getTopLeft(inSheet(find.byKey(profileSwitchModeKey))).dy;
      final tileTop = tester.getTopLeft(inSheet(find.byKey(profileAccessRequestsKey))).dy;
      final settingsTop = tester.getTopLeft(inSheet(find.byKey(profileSettingsKey))).dy;
      expect(switchTop, lessThan(tileTop));
      expect(tileTop, lessThan(settingsTop));
    });

    testWidgets('tapping it answers ProfileSheetAction.accessRequests', (tester) async {
      final answers = await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(user),
        policyState: const ConnectionPolicyLoaded(governed),
      );

      await tester.tap(inSheet(find.byKey(profileAccessRequestsKey)));
      await tester.pumpAndSettle();

      expect(answers, [ProfileSheetAction.accessRequests]);
    });

    testWidgets('reads Turkish', (tester) async {
      await pumpSheet(
        tester,
        identityState: const StudioIdentityLoaded(user),
        policyState: const ConnectionPolicyLoaded(governed),
        language: 'tr',
      );

      expect(inSheet(find.text('Erişim talepleri')), findsOneWidget);
    });
  });
}
