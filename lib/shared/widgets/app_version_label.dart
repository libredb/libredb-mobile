import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/utils/app_constants.dart';

/// The build this is, as `v1.2.3+45`, centred and quiet.
///
/// It takes nothing and reads nothing but two compile-time constants, which is why it does not belong to the page
/// that happened to show it first: onboarding's last panel and the settings footer want the same line.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'v${AppConstants.appVersion}+${AppConstants.appBuildNumber}',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
      ),
    );
  }
}
