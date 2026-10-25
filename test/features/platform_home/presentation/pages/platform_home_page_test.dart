@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/platform_home/presentation/pages/platform_home_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/widgets/platform_identity_scope.dart';

const _identity = PlatformIdentity(
  id: 'u1',
  email: 'platform.admin@example.org',
  name: 'Platform Admin',
  roles: ['PLATFORM_ADMIN'],
  permissions: [],
  tenant: PlatformTenant(id: 't1', name: 'Example Org', slug: 'example-org'),
);

void main() {
  late int retries;

  setUp(() => retries = 0);

  Future<void> pumpHome(WidgetTester tester, {PlatformIdentity? identity, bool failed = false}) async {
    final router = GoRouter(
      initialLocation: ApplicationRoutesConstants.platformHome,
      routes: [
        GoRoute(path: ApplicationRoutesConstants.platformHome, builder: (_, _) => const PlatformHomePage()),
        GoRoute(
          path: ApplicationRoutesConstants.platformConnections,
          builder: (_, _) => const Text('connections list'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        routerConfig: router,
        builder: (context, child) => PlatformIdentityScope(
          identity: identity,
          failed: failed,
          onRetry: () => retries++,
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  testWidgets('shows the tenant name and slug, the admin name and the Platform admin label', (tester) async {
    await pumpHome(tester, identity: _identity);
    await tester.pumpAndSettle();

    expect(find.text('Example Org'), findsOneWidget);
    expect(find.text('example-org'), findsOneWidget);
    expect(find.text('Platform Admin'), findsOneWidget);
    expect(find.text('Platform admin'), findsOneWidget);
    expect(find.text('platform.admin@example.org'), findsNothing);
  });

  testWidgets('falls back to the e-mail when Platform has no name', (tester) async {
    await pumpHome(
      tester,
      identity: const PlatformIdentity(
        id: 'u1',
        email: 'platform.admin@example.org',
        roles: ['PLATFORM_ADMIN'],
        permissions: [],
        tenant: PlatformTenant(id: 't1', name: 'Example Org', slug: 'example-org'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('platform.admin@example.org'), findsOneWidget);
  });

  testWidgets('shows the skeleton before the identity loads', (tester) async {
    await pumpHome(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppSkeleton), findsWidgets);
    expect(find.byType(AppErrorState), findsNothing);
  });

  testWidgets('shows the error with a retry that asks for the identity again', (tester) async {
    await pumpHome(tester, failed: true);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Could not load your Platform account'), findsOneWidget);

    await tester.tap(find.text('Retry'));

    expect(retries, 1);
  });

  testWidgets('its shortcut opens the connections list', (tester) async {
    await pumpHome(tester, identity: _identity);
    await tester.pumpAndSettle();

    await tester.tap(find.text('See every connection of this install.'));
    await tester.pumpAndSettle();

    expect(find.text('connections list'), findsOneWidget);
  });

  testWidgets('offers the shortcut while the identity is still loading', (tester) async {
    await pumpHome(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('See every connection of this install.'), findsOneWidget);
  });
}
