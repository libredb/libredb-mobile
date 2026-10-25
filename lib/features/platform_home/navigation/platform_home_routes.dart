import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/platform_home/presentation/pages/platform_home_page.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';

class PlatformHomeFeatureRoutes {
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'platformHome',
      path: ApplicationRoutesConstants.platformHome,
      pageBuilder: (context, state) =>
          appTransitionPage(state: state, type: AppPageTransitionType.fade, child: const PlatformHomePage()),
    ),
  ];
}
