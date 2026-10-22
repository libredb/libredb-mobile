import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_list_providers.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:go_router/go_router.dart';

class ConnectionsFeatureRoutes {
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'connectionList',
      path: ApplicationRoutesConstants.connectionList,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.fade,
        child: const ConnectionListProviders(child: ConnectionListPage()),
      ),
    ),
  ];
}
