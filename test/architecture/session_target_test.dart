import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/shell/shell_tabs.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessionCubit extends Mock implements SessionCubit {}

/// Every session target has its own home, tabs and settings, each a route the router builds, and the home belongs to
/// its own target only, so a session of one target never lands in the other's shell.
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
    });
  }
}
