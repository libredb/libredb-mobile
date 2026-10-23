import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/browse_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/container_level_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/key_browser_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/kind_counts_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_detail_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_list_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_rows_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_search_page.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/object_source_page.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';

/// The Browse tab: its root, which follows the active connection, and the pages under it, which take their connection
/// and container from the route.
class ObjectBrowserFeatureRoutes {
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: BrowseRouteNames.browse,
      path: ApplicationRoutesConstants.browse,
      pageBuilder: (context, state) =>
          appTransitionPage(state: state, type: AppPageTransitionType.fade, child: const BrowsePage()),
      routes: [
        GoRoute(
          name: BrowseRouteNames.containers,
          path: ApplicationRoutesConstants.browseContainers,
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            type: AppPageTransitionType.slideRight,
            child: ContainerLevelPage(connectionId: browseConnectionIdOf(state), parent: browseContainerOf(state)),
          ),
        ),
        GoRoute(
          name: BrowseRouteNames.kinds,
          path: ApplicationRoutesConstants.browseKinds,
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            type: AppPageTransitionType.slideRight,
            child: KindCountsPage(connectionId: browseConnectionIdOf(state), container: browseContainerOf(state)),
          ),
        ),
        GoRoute(
          name: BrowseRouteNames.objects,
          path: ApplicationRoutesConstants.browseObjects,
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            type: AppPageTransitionType.slideRight,
            child: ObjectListPage(
              connectionId: browseConnectionIdOf(state),
              container: browseContainerOf(state),
              kind: browseKindOf(state),
            ),
          ),
        ),
        GoRoute(
          name: BrowseRouteNames.source,
          path: ApplicationRoutesConstants.browseSource,
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            type: AppPageTransitionType.slideRight,
            child: ObjectSourcePage(
              connectionId: browseConnectionIdOf(state),
              path: browsePathOf(state),
              kind: browseKindOf(state),
            ),
          ),
        ),
        GoRoute(
          name: BrowseRouteNames.keys,
          path: ApplicationRoutesConstants.browseKeys,
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            type: AppPageTransitionType.slideRight,
            child: KeyBrowserPage(
              connectionId: browseConnectionIdOf(state),
              container: browseContainerOf(state),
              prefix: browsePrefixOf(state),
            ),
          ),
        ),
        GoRoute(
          name: BrowseRouteNames.detail,
          path: ApplicationRoutesConstants.browseDetail,
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            type: AppPageTransitionType.slideRight,
            child: ObjectDetailPage(
              connectionId: browseConnectionIdOf(state),
              path: browsePathOf(state),
              kind: browseKindOf(state),
            ),
          ),
        ),
        GoRoute(
          name: BrowseRouteNames.rows,
          path: ApplicationRoutesConstants.browseRows,
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            type: AppPageTransitionType.slideRight,
            child: ObjectRowsPage(
              connectionId: browseConnectionIdOf(state),
              path: browsePathOf(state),
              kind: browseKindOf(state),
            ),
          ),
        ),
        GoRoute(
          name: BrowseRouteNames.search,
          path: ApplicationRoutesConstants.browseSearch,
          pageBuilder: (context, state) => appTransitionPage(
            state: state,
            type: AppPageTransitionType.slideRight,
            child: ObjectSearchPage(connectionId: browseConnectionIdOf(state)),
          ),
        ),
      ],
    ),
  ];
}
