import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_page.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:go_router/go_router.dart';

class SettingsFeatureRoutes {
  /// The settings route at [path] under [name], one per shell: go_router wants every route name once, and analytics
  /// logs a page by its name. [securitySection] builds the rows of its Security section, which the app composes from
  /// another feature (see [SettingsPage.securitySection]).
  static List<GoRoute> routes({required String path, required String name, WidgetBuilder? securitySection}) => [
    GoRoute(
      name: name,
      path: path,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.fade,
        child: SettingsPage(securitySection: securitySection),
      ),
    ),
  ];
}
