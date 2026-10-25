@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/features/platform_grants/navigation/platform_grants_routes.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/pages/platform_connection_grants_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

const _orders = PlatformConnection(
  id: 'c 1',
  name: 'Orders',
  engine: 'postgres',
  status: 'active',
  hasWriteCredential: true,
);

void main() {
  late MockIPlatformGrantRepository repository;

  setUp(() {
    repository = MockIPlatformGrantRepository();
    when(() => repository.list(any())).thenAnswer((_) async => const Success([]));
  });

  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: ApplicationRoutesConstants.platformConnections,
      routes: [
        GoRoute(
          path: ApplicationRoutesConstants.platformConnections,
          builder: (_, _) => const Text('connections list'),
        ),
        ...PlatformGrantsFeatureRoutes.routes,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<IPlatformGrantRepository>.value(
        value: repository,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          routerConfig: router,
          builder: (context, child) => Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the route is named, so analytics logs it by name and not by its location', (tester) async {
    expect(PlatformGrantsFeatureRoutes.routes.first.name, 'platformConnectionGrants');
    expect(PlatformGrantsFeatureRoutes.routes.first.path, ApplicationRoutesConstants.platformConnectionGrants);
  });

  testWidgets('opens the grants of the connection passed as extra', (tester) async {
    final router = await pumpRouter(tester);

    router.push('/platform/connections/${Uri.encodeComponent(_orders.id)}', extra: _orders);
    await tester.pumpAndSettle();

    expect(find.byType(PlatformConnectionGrantsPage), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    verify(() => repository.list('c 1')).called(1);
  });

  testWidgets('goes to the connections list when no connection is passed as extra', (tester) async {
    final router = await pumpRouter(tester);

    router.go('/platform/connections/c1');
    await tester.pumpAndSettle();

    expect(find.byType(PlatformConnectionGrantsPage), findsNothing);
    expect(find.text('connections list'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, ApplicationRoutesConstants.platformConnections);
    verifyNever(() => repository.list(any()));
  });

  testWidgets('goes to the connections list when extra is something else', (tester) async {
    final router = await pumpRouter(tester);

    router.go('/platform/connections/c1', extra: 'c1');
    await tester.pumpAndSettle();

    expect(find.text('connections list'), findsOneWidget);
  });
}
