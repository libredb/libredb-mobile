import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/platform_audit/navigation/audit_event_args.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/pages/audit_event_page.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/pages/audit_log_page.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/widgets/audit_log_providers.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';

class PlatformAuditFeatureRoutes {
  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'platformAudit',
      path: ApplicationRoutesConstants.platformAudit,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.fade,
        child: const AuditLogProviders(child: AuditLogPage()),
      ),
    ),
    GoRoute(
      name: 'platformAuditEvent',
      path: ApplicationRoutesConstants.platformAuditEvent,
      // The page shows the event the list handed over. A location reached any other way, such as a returnUrl after
      // sign-in, a typed location or a process restart, carries none, and Platform has no route that reads one event,
      // so it opens the list.
      redirect: (context, state) => state.extra is AuditEventArgs ? null : ApplicationRoutesConstants.platformAudit,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.slideRight,
        child: AuditEventPage(args: state.extra! as AuditEventArgs),
      ),
    ),
  ];
}
