@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/login_brand_icon.dart';
import 'package:libredb_mobile/shared/design_system/brand/brand_mark.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

/// The mark above the sign-in heading is the product's, not a glyph that resembles it.
///
/// It was `Icons.bolt_rounded` in a bordered tile — a stock Material lightning bolt, which says "some app" and
/// names no product. M15's first child is that the login screen reads as LibreDB's own, and a mark the framework
/// ships with is the one thing on the page that cannot (#284, #390).
void main() {
  Future<void> pumpIcon(WidgetTester tester, {bool dark = false}) => tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(
        body: Center(child: LoginBrandIcon(isDark: dark)),
      ),
    ),
  );

  for (final dark in [false, true]) {
    final brightness = dark ? 'dark' : 'light';

    testWidgets('in $brightness it draws the product mark', (tester) async {
      await pumpIcon(tester, dark: dark);

      expect(find.byType(BrandMark), findsOneWidget);
    });

    testWidgets('in $brightness it draws no Material glyph in its place', (tester) async {
      await pumpIcon(tester, dark: dark);

      expect(
        find.byType(Icon),
        findsNothing,
        reason: 'a stock glyph beside the real mark would be two marks, and one of them is not the product',
      );
    });
  }

  testWidgets('it keeps the footprint the heading was laid out around', (tester) async {
    // The tile it replaces was 44 pt tall. The mark is taller than it is wide, so the width follows from that
    // rather than the other way round — a layout that was built for 44 keeps working.
    await pumpIcon(tester);

    expect(tester.getSize(find.byType(BrandMark)).height, closeTo(44, 0.5));
  });
}
