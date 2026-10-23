import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/pages/sql_page.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:libredb_mobile/shared/models/editor_open_request.dart';

class SqlEditorFeatureRoutes {
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'sql',
      path: ApplicationRoutesConstants.sql,
      // An open request (openEditor) arrives as the extra, never in the location.
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.fade,
        child: SqlPage(
          delivery: switch (state.extra) {
            final EditorOpenDelivery delivery => delivery,
            _ => null,
          },
        ),
      ),
    ),
  ];
}
