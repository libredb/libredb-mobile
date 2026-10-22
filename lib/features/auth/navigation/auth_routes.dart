import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:go_router/go_router.dart';

class AuthFeatureRoutes {
  /// The public route, the login page, outside ShellRoute. The identity provider owns the password, so the app has no
  /// registration or password page. [loginBuilder] lets the router inject app-level bindings (e.g. ThemeBloc) without
  /// making this file import `app/`.
  static List<GoRoute> publicRoutes({Widget Function(BuildContext context)? loginBuilder}) => [
    GoRoute(
      name: 'login',
      path: ApplicationRoutesConstants.login,
      pageBuilder: (context, state) =>
          appPlatformPage(state: state, child: loginBuilder?.call(context) ?? const LoginScreen()),
    ),
  ];
}
