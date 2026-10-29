import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/access_requests/domain/repositories/access_request_repository.dart';
import 'package:libredb_mobile/features/access_requests/navigation/access_requests_routes.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../support/unsaved_changes_host.dart';

/// The app text in English, for a test that names a refusal by the text it shows.
Future<S> loadEnglish() => S.delegate.load(const Locale('en'));

/// The two routes of the feature under a stub connection list, as the Studio shell composes them, with [repository]
/// and the unsaved-changes registry above the router. The test opens [location] by a push, so the connection list is
/// under it and a back has somewhere to go.
Future<GoRouter> pumpAccessRequests(
  WidgetTester tester,
  IAccessRequestRepository repository, {
  String? location = ApplicationRoutesConstants.accessRequests,
  bool available = true,
  Locale locale = const Locale('en'),
}) async {
  // Tall, so a list of rows is built whole and no row waits below the fold.
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(800, 2000);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: ApplicationRoutesConstants.connectionList,
    routes: [
      GoRoute(
        path: ApplicationRoutesConstants.connectionList,
        builder: (_, _) => const Scaffold(body: Text('connection list')),
      ),
      ...AccessRequestsFeatureRoutes.routes(isAvailable: (_) => available),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    withUnsavedChangesRegistry(
      RepositoryProvider<IAccessRequestRepository>.value(
        value: repository,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (location != null) {
    router.push(location);
    await tester.pumpAndSettle();
  }
  return router;
}
