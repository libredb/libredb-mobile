@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/local_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_sign_out_auth_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/cached_object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

import '../../support/test_env.dart';
import '../../support/user_menu.dart';

/// How AppSessionListeners connects the active connection to the session and to the caches of #53.
void main() {
  const billing = 'seed:billing-mysql';
  const sales = 'seed:sales-postgres';

  Finder row(String id) => find.byKey(ValueKey('connection-row-$id'));

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TestEnv.authenticate();
    await tester.pumpWidget(App(dependencies: _Dependencies(), language: 'en'));
    await tester.pumpAndSettle();
    expect(find.byType(ResponsiveScaffold), findsOneWidget);
  }

  ActiveConnectionCubit activeOf(WidgetTester tester) =>
      tester.element(find.byType(ResponsiveScaffold)).read<ActiveConnectionCubit>();

  Future<void> logOut(WidgetTester tester) async {
    await selectFromUserMenu(tester, Icons.logout);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();
    await tester.pump(SsoSignOutAuthRepository.defaultStudioSignOutTimeout);
    await tester.pumpAndSettle();
  }

  testWidgets('a logout closes the connection and the same user gets it back on the next sign-in', (tester) async {
    await launch(tester);
    await tester.tap(row(billing));
    await tester.pumpAndSettle();
    final active = activeOf(tester);
    expect(active.state.connection?.id, billing);

    await logOut(tester);
    expect(active.state, const ActiveConnectionNone());

    await tester.tap(find.byKey(loginButtonSsoKey));
    await tester.pumpAndSettle();

    expect(active.state.connection?.id, billing);
  });

  testWidgets('opening a connection, and each switch, drops the expired object answers', (tester) async {
    await launch(tester);
    final browser =
        tester.element(find.byType(ResponsiveScaffold)).read<CachedObjectBrowserRepository>()
            as _CountingObjectBrowserRepository;
    expect(browser.evictions, 0);

    activeOf(tester).select(const _Connection(billing));
    await tester.pump();
    expect(browser.evictions, 1);

    activeOf(tester).select(const _Connection(sales));
    await tester.pump();
    expect(browser.evictions, 2);

    // The same connection again, as a list refresh hands it over, is no switch.
    activeOf(tester).select(const _Connection(sales));
    await tester.pump();
    expect(browser.evictions, 2);
  });

  testWidgets('a vanished connection drops its object and provider-meta answers and keeps the others', (tester) async {
    await launch(tester);
    final scope = tester.element(find.byType(ResponsiveScaffold));
    final browser = scope.read<CachedObjectBrowserRepository>();
    final providerMeta = scope.read<CachedProviderMetaRepository>();
    final answers = await tester.runAsync(
      () => Future.wait([
        browser.containers(billing),
        providerMeta.providerMeta(billing),
        browser.containers(sales),
        providerMeta.providerMeta(sales),
      ]),
    );
    expect(answers, everyElement(isA<Success<Object>>()));
    expect((browser.entryCount, providerMeta.entryCount), (2, 2));

    activeOf(tester).select(const _Connection(billing));
    activeOf(tester).reportUnavailable(billing);
    await tester.pump();

    expect((browser.entryCount, providerMeta.entryCount), (1, 1));
  });
}

class _Connection extends StudioConnection {
  const _Connection(String id) : super(id: id, name: id, type: 'postgres');
}

class _Dependencies extends LocalSignInDependencies {
  @override
  CachedObjectBrowserRepository createObjectBrowserRepository(ApiClient apiClient) =>
      _CountingObjectBrowserRepository(ObjectBrowserRepository(apiClient));
}

/// Counts the evictions of expired answers, which the cache does by time and a test cannot see in its entries.
class _CountingObjectBrowserRepository extends CachedObjectBrowserRepository {
  _CountingObjectBrowserRepository(super.inner);

  int evictions = 0;

  @override
  void evictExpired() {
    evictions++;
    super.evictExpired();
  }
}
