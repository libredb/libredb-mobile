import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/browse_page.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';

class ObjectBrowserFeatureRoutes {
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'browse',
      path: ApplicationRoutesConstants.browse,
      pageBuilder: (context, state) =>
          appTransitionPage(state: state, type: AppPageTransitionType.fade, child: const BrowsePage()),
    ),
  ];
}
