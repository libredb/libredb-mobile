import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_page.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:go_router/go_router.dart';

class SettingsFeatureRoutes {
  /// The settings route; [securitySection] builds the rows of its Security section, which the app composes from
  /// another feature (see [SettingsPage.securitySection]).
  static List<GoRoute> routes({WidgetBuilder? securitySection}) => [
    GoRoute(
      name: 'settings',
      path: ApplicationRoutesConstants.settings,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.fade,
        child: SettingsPage(securitySection: securitySection),
      ),
    ),
  ];
}
