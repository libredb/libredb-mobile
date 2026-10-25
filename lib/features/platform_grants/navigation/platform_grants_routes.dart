import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/pages/platform_connection_grants_page.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/widgets/platform_grants_providers.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

class PlatformGrantsFeatureRoutes {
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'platformConnectionGrants',
      path: ApplicationRoutesConstants.platformConnectionGrants,
      // The page shows the connection the list handed over. A location reached any other way, such as a returnUrl
      // after sign-in, a typed location or a process restart, carries none, and Platform has no route that reads one
      // connection, so it opens the connections list.
      redirect: (context, state) =>
          state.extra is PlatformConnection ? null : ApplicationRoutesConstants.platformConnections,
      pageBuilder: (context, state) {
        final connection = state.extra! as PlatformConnection;
        return appTransitionPage(
          state: state,
          type: AppPageTransitionType.slideRight,
          child: PlatformGrantsProviders(
            connection: connection,
            child: PlatformConnectionGrantsPage(connection: connection),
          ),
        );
      },
    ),
  ];
}
