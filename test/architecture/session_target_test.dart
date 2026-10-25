import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/app_status_gate.dart';
import 'package:libredb_mobile/app/router/app_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/shell/shell_tabs.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_state.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_unreachable_page.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_unreachable_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mock_classes.dart';

class _MockSessionCubit extends Mock implements SessionCubit {}

class _MockSessionStateCubit extends MockCubit<SessionState> implements SessionCubit {}

/// The unreachable page of the liveness gate of [target]: each target's session is covered only by its own server's.
Type _unreachablePageOf(SessionTarget target) => switch (target) {
  SessionTarget.studio => StudioUnreachablePage,
  SessionTarget.platform => PlatformUnreachablePage,
};

/// Every session target has its own home, tabs and settings, each a route the router builds, and the home belongs to
/// its own target only, so a session of one target never lands in the other's shell. Each target has its own liveness
/// gate, which covers that target's session and not the other's.
const _down = NetworkError('No Internet connection');

void main() {
  late GoRouter router;

  setUp(() {
    final session = _MockSessionCubit();
    when(() => session.state).thenReturn(const SessionUnknown());
    when(() => session.stream).thenAnswer((_) => const Stream<SessionState>.empty());
    router = AppRouterFactory(sessionCubit: session).create();
    addTearDown(router.dispose);
  });

  bool builds(String route) {
    final match = router.configuration.findMatch(Uri.parse(route));
    return match.isNotEmpty && !match.isError;
  }

  for (final target in SessionTarget.values) {
    final other = SessionTarget.values.firstWhere((value) => value != target);

    group(target.name, () {
      test('its home, tabs and settings are routes the router builds', () {
        final routes = [
          ApplicationRoutesConstants.homeFor(target),
          ...ApplicationRoutesConstants.tabsFor(target),
          ApplicationRoutesConstants.settingsFor(target),
        ];
        for (final route in routes) {
          expect(builds(route), isTrue, reason: route);
        }
      });

      test('its home belongs to it and not to ${other.name}', () {
        final home = ApplicationRoutesConstants.homeFor(target);

        expect(ApplicationRoutesConstants.belongsTo(target, home), isTrue);
        expect(ApplicationRoutesConstants.belongsTo(other, home), isFalse);
      });

      test('its tabs and settings belong to it and not to ${other.name}', () {
        for (final route in [
          ...ApplicationRoutesConstants.tabsFor(target),
          ApplicationRoutesConstants.settingsFor(target),
        ]) {
          expect(ApplicationRoutesConstants.belongsTo(target, route), isTrue, reason: route);
          expect(ApplicationRoutesConstants.belongsTo(other, route), isFalse, reason: route);
        }
      });

      test('the shell tab descriptors follow its tabs, in order', () {
        expect(shellTabsFor(target).map((tab) => tab.route).toList(), ApplicationRoutesConstants.tabsFor(target));
      });

      // Both servers are down: a session of this target shows its own server's page, never the other's.
      testWidgets('its session is covered by its own gate and not by the ${other.name} gate', (tester) async {
        final session = _MockSessionStateCubit();
        whenListen(session, const Stream<SessionState>.empty(), initialState: SessionAuthenticated(target: target));
        final studio = MockStudioStatusBloc();
        whenListen(
          studio,
          const Stream<StudioStatusState>.empty(),
          initialState: const StudioUnreachable(error: _down),
        );
        final platform = MockPlatformStatusBloc();
        whenListen(
          platform,
          const Stream<PlatformStatusState>.empty(),
          initialState: const PlatformUnreachable(error: _down),
        );

        await tester.pumpWidget(
          RepositoryProvider<AppConfig>.value(
            value: const AppConfig(
              environment: Environment.mock,
              apiBaseUrl: null,
              certificatePins: [],
              idleTimeout: null,
              platform: PlatformConfigured(),
            ),
            child: MultiBlocProvider(
              providers: [
                BlocProvider<SessionCubit>.value(value: session),
                BlocProvider<StudioStatusBloc>.value(value: studio),
                BlocProvider<PlatformStatusBloc>.value(value: platform),
              ],
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: const [
                  S.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: S.delegate.supportedLocales,
                builder: (context, _) => const AppStatusGate(child: SizedBox()),
              ),
            ),
          ),
        );

        expect(find.byType(_unreachablePageOf(target)), findsOneWidget);
        expect(find.byType(_unreachablePageOf(other)), findsNothing);
      });
    });
  }

  test('Platform has the tabs Home, Connections and Audit, in this order', () {
    expect(ApplicationRoutesConstants.tabsFor(SessionTarget.platform), [
      ApplicationRoutesConstants.platformHome,
      ApplicationRoutesConstants.platformConnections,
      ApplicationRoutesConstants.platformAudit,
    ]);
  });

  test('Studio keeps the tabs Connections, Browse and SQL', () {
    expect(ApplicationRoutesConstants.tabsFor(SessionTarget.studio), [
      ApplicationRoutesConstants.connectionList,
      ApplicationRoutesConstants.browse,
      ApplicationRoutesConstants.sql,
    ]);
  });
}
