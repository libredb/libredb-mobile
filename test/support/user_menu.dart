import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';

/// Opens the user menu in the top bar of the shell and taps its entry with [icon], as the user does: [Icons.logout]
/// signs out, [Icons.settings_outlined] opens the settings.
Future<void> selectFromUserMenu(WidgetTester tester, IconData icon) async {
  await tester.tap(find.descendant(of: find.byType(TopBarWidget), matching: find.byType(PopupMenuButton<String>)));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithIcon(PopupMenuItem<String>, icon));
  await tester.pumpAndSettle();
}
