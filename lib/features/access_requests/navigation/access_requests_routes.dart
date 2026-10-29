import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/access_requests/presentation/pages/access_request_form_page.dart';
import 'package:libredb_mobile/features/access_requests/presentation/pages/my_access_requests_page.dart';
import 'package:libredb_mobile/features/access_requests/presentation/widgets/access_request_providers.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:libredb_mobile/shared/widgets/unsaved_changes_guard.dart';

/// The two pages of the access requests of a Studio user: "My requests" and the form.
class AccessRequestsFeatureRoutes {
  /// Both routes redirect to the connection list unless [isAvailable] holds, so a typed location or a `returnUrl` never
  /// sends a Platform request outside the visibility rule. The predicate lives in `lib/app/`, since this feature must
  /// not read the connection policy of another feature.
  static List<GoRoute> routes({required bool Function(BuildContext context) isAvailable}) => [
    GoRoute(
      name: 'accessRequests',
      path: ApplicationRoutesConstants.accessRequests,
      redirect: (context, state) => isAvailable(context) ? null : ApplicationRoutesConstants.connectionList,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.slideRight,
        child: const MyAccessRequestsProviders(child: MyAccessRequestsPage()),
      ),
    ),
    GoRoute(
      name: 'accessRequestNew',
      path: ApplicationRoutesConstants.accessRequestNew,
      redirect: (context, state) => isAvailable(context) ? null : ApplicationRoutesConstants.connectionList,
      // The form asks before it is left with a reason written.
      onExit: confirmLeavingUnsavedChanges,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.slideRight,
        child: const AccessRequestFormProviders(child: AccessRequestFormPage()),
      ),
    ),
  ];
}
