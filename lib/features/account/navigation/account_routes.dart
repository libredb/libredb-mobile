import 'package:libredb_mobile/features/account/presentation/pages/account_page.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:libredb_mobile/shared/widgets/unsaved_changes_guard.dart';
import 'package:go_router/go_router.dart';

class AccountFeatureRoutes {
  static final List<GoRoute> routes = [
    GoRoute(
      path: '/account',
      onExit: confirmLeavingUnsavedChanges,
      pageBuilder: (context, state) =>
          appTransitionPage(state: state, type: AppPageTransitionType.slideRight, child: const AccountPage()),
    ),
  ];
}
