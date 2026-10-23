@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_switcher_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

import '../../support/test_env.dart';

/// The active connection end to end, in the real app on the mocked API, with a connection list that a test can take a
/// connection out of, as an operator revoking a grant does.
void main() {
  const billing = 'seed:billing-mysql';
  const billingName = 'Billing (MySQL)';

  late _RevocableConnections connections;

  setUp(() => connections = _RevocableConnections());

  GoRouter routerOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

  Finder inTopBar(Finder finder) => find.descendant(of: find.byType(TopBarWidget), matching: finder);
  Finder row(String id) => find.byKey(ValueKey('connection-row-$id'));

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TestEnv.authenticate();
    await tester.pumpWidget(App(dependencies: _Dependencies(connections), language: 'en'));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionListPage), findsOneWidget);
  }

  Future<void> openBilling(WidgetTester tester) async {
    await tester.tap(row(billing));
    await tester.pumpAndSettle();
  }

  testWidgets('a tap on a connection opens Browse with its name in the top bar', (tester) async {
    await launch(tester);

    await openBilling(tester);

    // Browse opens the connection's first level, which goes on to the session-default schema of the mocked answer.
    expect(routerOf(tester).state.uri.path, '/browse/seed%3Abilling-mysql/kinds');
    expect(routerOf(tester).state.uri.queryParametersAll['container'], ['public']);
    expect(inTopBar(find.text(billingName)), findsOneWidget);
    expect(inTopBar(find.text('PROD')), findsOneWidget);
    expect(inTopBar(find.byIcon(Icons.lock_outline)), findsOneWidget);
  });

  testWidgets('a relaunch opens the last connection again', (tester) async {
    await launch(tester);
    await openBilling(tester);

    // The app is closed and started again: the device keeps its preferences and the stored session.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await launch(tester);
    routerOf(tester).go(ApplicationRoutesConstants.browse);
    await tester.pumpAndSettle();

    expect(inTopBar(find.text(billingName)), findsOneWidget);
  });

  testWidgets('the switcher in the top bar switches to another connection', (tester) async {
    await launch(tester);
    await openBilling(tester);

    await tester.tap(inTopBar(find.text(billingName)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ConnectionSwitcherSheet), matching: row('seed:catalog-mongo')));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectionSwitcherSheet), findsNothing);
    // The switch returns Browse to its root, which opens the new connection as a first entry.
    expect(routerOf(tester).state.uri.path, '/browse/seed%3Acatalog-mongo/kinds');
    expect(inTopBar(find.text('Product Catalog (MongoDB)')), findsOneWidget);
  });

  testWidgets('a refresh without the open connection says it is no longer available and returns to Connections', (
    tester,
  ) async {
    await launch(tester);
    await openBilling(tester);
    connections.revoke(billing);

    // The switcher asks Studio for the list again.
    await tester.tap(inTopBar(find.text(billingName)));
    await tester.pumpAndSettle();

    // The sheet closes, so the message is not hidden under it.
    expect(find.byType(ConnectionSwitcherSheet), findsNothing);
    expect(find.text(S.current.connection_vanished(billingName)).hitTestable(), findsOneWidget);
    expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
  });

  testWidgets('a pull to refresh on Connections without the open connection says it is no longer available', (
    tester,
  ) async {
    await launch(tester);
    await openBilling(tester);
    routerOf(tester).go(ApplicationRoutesConstants.connectionList);
    await tester.pumpAndSettle();
    connections.revoke(billing);

    await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text(S.current.connection_vanished(billingName)), findsOneWidget);
    expect(routerOf(tester).state.uri.path, ApplicationRoutesConstants.connectionList);
    expect(row(billing), findsNothing);

    routerOf(tester).go(ApplicationRoutesConstants.browse);
    await tester.pumpAndSettle();
    expect(inTopBar(find.text(billingName)), findsNothing);
    expect(inTopBar(find.text(S.current.tab_browse)), findsOneWidget);
  });
}

class _Dependencies extends LocalSignInDependencies {
  _Dependencies(this._connections);

  final _RevocableConnections _connections;

  @override
  IConnectionRepository createConnectionRepository(ApiClient apiClient, ConnectionQueryTimeouts queryTimeouts) =>
      _connections..inner = ConnectionRepository(apiClient, queryTimeouts);
}

/// The mocked API's connections, less the ones [revoke] took out.
class _RevocableConnections implements IConnectionRepository {
  late IConnectionRepository inner;
  final _revoked = <String>{};

  void revoke(String id) => _revoked.add(id);

  @override
  Future<Result<ManagedConnections>> listManaged() async {
    final result = await inner.listManaged();
    return switch (result) {
      Success(:final data) => Success(
        ManagedConnections(
          connections: [
            for (final StudioConnection c in data.connections)
              if (!_revoked.contains(c.id)) c,
          ],
          cacheHint: data.cacheHint,
        ),
      ),
      Failure() => result,
    };
  }

  @override
  Future<Result<ConnectionPolicy>> fetchPolicy() => inner.fetchPolicy();

  @override
  Future<Result<ConnectionTestResult>> test(String connectionId) => inner.test(connectionId);
}
