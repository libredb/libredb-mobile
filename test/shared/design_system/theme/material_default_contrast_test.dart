@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';

/// Guards the text this app never colours — the labels Flutter's own Material 3 defaults supply.
///
/// `palette_contrast_test.dart` measures the roles; `semantic_contrast_test.dart` and the token guards measure what
/// this app's own code paints with them. None of them can see a colour that comes from neither, and three of those
/// exist: `TextButton`, `OutlinedButton` and `TabBar` are given a size, a shape and a text style in
/// `app_theme.dart` and no foreground colour, so `_TextButtonDefaultsM3`, `_OutlinedButtonDefaultsM3` and
/// `TabBarTheme`'s default supply one — `colorScheme.primary`.
///
/// That was harmless while `primary` was a near-white or a near-black. It stopped being harmless when #283 pointed
/// it at the product's indigo, which is 6.29:1 on a light page and **3.08:1** on a dark one: every quiet button in
/// the app — "Skip" on the welcome screen, every dialog's "Cancel", every "Retry" — and the selected tab of the
/// object detail page fell under the floor at once, and nothing in the repository was looking. The emulator was:
/// this guard exists because a screenshot showed an indigo "Skip" on a near-black page.
///
/// It pumps the real widgets under the real theme rather than reading the `ThemeData`, because what is guarded is
/// precisely the value the theme does *not* carry. A role with no call site in `lib/` is not a role nobody sees.
void main() {
  Color labelOf(WidgetTester tester, Type widget) => tester
      .firstWidget<RichText>(find.descendant(of: find.byType(widget), matching: find.byType(RichText)))
      .text
      .style!
      .color!;

  for (final palette in AppThemePalette.values) {
    for (final brightness in Brightness.values) {
      testWidgets('${palette.name} in ${brightness.name}: the labels Material colours can be read', (tester) async {
        final scheme = ThemeColors.getColorScheme(palette, brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light ? AppTheme.light(palette) : AppTheme.dark(palette),
            home: DefaultTabController(
              length: 2,
              child: Scaffold(
                body: Column(
                  children: [
                    TextButton(onPressed: () {}, child: const Text('Skip')),
                    OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
                    const TabBar(tabs: [Tab(text: 'Columns'), Tab(text: 'Source')]),
                  ],
                ),
              ),
            ),
          ),
        );

        final under = <String>[];
        for (final (what, widget) in [
          ("a text button's label", TextButton),
          ("an outlined button's label", OutlinedButton),
          ("the selected tab's label", Tab),
        ]) {
          final ratio = contrastRatio(labelOf(tester, widget), scheme.surface);
          if (ratio < 4.5) under.add('$what: ${ratio.toStringAsFixed(2)}:1, floor 4.5:1');
        }

        expect(under, isEmpty, reason: 'in ${palette.name}/${brightness.name}:\n${under.join('\n')}');
      });
    }
  }
}
