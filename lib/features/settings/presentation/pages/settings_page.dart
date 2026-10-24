import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.securitySection});

  /// See [SettingsScreen.securitySection].
  final WidgetBuilder? securitySection;

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(securitySection: securitySection);
  }
}
