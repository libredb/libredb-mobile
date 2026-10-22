import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';

/// Opens the profile sheet from the avatar in the top bar of the shell and taps its entry with [icon], as the user
/// does: [Icons.logout] signs out, [Icons.settings_outlined] opens the settings.
Future<void> selectFromUserMenu(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byKey(profileButtonKey));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(ProfileSheet), matching: find.widgetWithIcon(ListTile, icon)));
  await tester.pumpAndSettle();
}
