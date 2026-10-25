import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/pages/platform_connection_list_page.dart';
import 'package:libredb_mobile/features/platform_connections/presentation/widgets/connection_list_providers.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';

class PlatformConnectionsFeatureRoutes {
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'platformConnections',
      path: ApplicationRoutesConstants.platformConnections,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.fade,
        child: const PlatformConnectionListProviders(child: PlatformConnectionListPage()),
      ),
    ),
  ];
}
