@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_badge.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';

/// The shape of a badge, which is one shape across the app or it is noise.
///
/// `connection_badges.dart` drew its own at `circular(4)` while the design system's two badge components take
/// `AppRadius.pill`, so the same idea — a small label beside a connection — was a rounded rectangle on the Studio
/// side and a pill on the Platform side. The class is even called `_Pill` (#375).
void main() {
  Future<void> pump(WidgetTester tester, Widget subject, {TextScaler scaler = TextScaler.noScaling}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: Scaffold(body: Center(child: subject)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// What [subject] adds around its own words: its whole width less the width its `Text` renders at.
  ///
  /// The test font is Ahem, whose every glyph is a full em square, so the width of the words themselves means
  /// nothing here — but it is on both sides of this subtraction and cancels out, and what is left is the chip's own
  /// padding, borders and whatever else it puts beside the text. That number is the one the prototype fixes.
  double insetOf(WidgetTester tester, Finder subject) {
    final text = find.descendant(of: subject, matching: find.byType(Text));
    return tester.getSize(subject).width - tester.getSize(text.first).width;
  }

  /// The radius the badge's own box is drawn with.
  BorderRadius radiusOf(WidgetTester tester, Finder subject) {
    final box = find.descendant(of: subject, matching: find.byType(DecoratedBox)).first;
    final decoration = tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
    return decoration.borderRadius! as BorderRadius;
  }

  testWidgets('an environment badge is as round as the design system says', (tester) async {
    await pump(tester, const EnvironmentBadge(environment: 'production'));
    expect(radiusOf(tester, find.byType(EnvironmentBadge)), BorderRadius.circular(AppRadius.pill));
  });

  testWidgets('a read-only chip is as round as the design system says', (tester) async {
    await pump(tester, const ReadOnlyChip());
    expect(radiusOf(tester, find.byType(ReadOnlyChip)), BorderRadius.circular(AppRadius.pill));
  });

  // The approved prototype's own rule for this chip (`scratchpad/ob/ob.html`) is
  //
  //     .ro{font-family:var(--mono);font-size:11px;letter-spacing:.07em;padding:3px 6px;border-radius:999px;
  //      border:1px solid var(--edge);color:var(--quiet)}
  //
  // and measured in headless Chrome at 390x844 it draws 80.34 x 22 in English and 95.08 x 22 in Turkish around a
  // text box of 66.34 x 14 and 81.08 x 14. The chip's own contribution is therefore **14 pt across** — 6 + 6 of
  // padding and 1 + 1 of border — in both languages and at both themes. There is no icon in that rule.
  testWidgets('a read-only chip is the words and the design\'s own inset, nothing beside them', (tester) async {
    await pump(tester, const ReadOnlyChip());
    expect(insetOf(tester, find.byType(ReadOnlyChip)), 2 * AppSpacing.sm);
    expect(find.descendant(of: find.byType(ReadOnlyChip), matching: find.byType(Icon)), findsNothing);
  });

  testWidgets('and that inset is the same at an accessibility text size', (tester) async {
    await pump(tester, const ReadOnlyChip(), scaler: const TextScaler.linear(3));
    expect(insetOf(tester, find.byType(ReadOnlyChip)), 2 * AppSpacing.sm);
  });

  // The prototype's badge rule is
  //
  //     .bdg{font-family:var(--mono);font-size:11px;font-weight:700;letter-spacing:.1em;padding:3px 6px;
  //      border-radius:4px}
  //
  // and measured in headless Chrome at 390x844 it draws 42.81 x 20 for PROD in both languages and both themes, with
  // no border: 6 + 6 across and 3 + 3 down around a text box of 30.81 x 14. The device drew 50.2 because this badge
  // set its words in the sans face with no tracking and 8 + 8 of padding. Both insets are read against the badge's
  // own `Text`, so Ahem cancels out of the subtraction.
  testWidgets('the environment badge is the prototype\'s 6 across and 3 down around its words', (tester) async {
    await pump(tester, const EnvironmentBadge(environment: 'production'));
    final badge = find.byType(EnvironmentBadge);
    final text = tester.getSize(find.descendant(of: badge, matching: find.byType(Text)).first);
    expect(tester.getSize(badge).width - text.width, 12.0);
    expect(tester.getSize(badge).height - text.height, 6.0);
  });

  testWidgets('and its words are mono, tracked at a tenth of an em, as the prototype\'s are', (tester) async {
    await pump(tester, const EnvironmentBadge(environment: 'production'));
    final text = find.descendant(of: find.byType(EnvironmentBadge), matching: find.byType(Text));
    final style = tester.widget<Text>(text).style!;
    expect(style.fontFamily, AppTypography.mono);
    expect(style.fontSize, 11.0);
    expect(style.fontWeight, FontWeight.w700);
    expect(style.letterSpacing, closeTo(1.1, 1e-9));
  });

  testWidgets('and that is the same shape AppBadge draws', (tester) async {
    await pump(tester, const AppBadge(label: 'x'));
    expect(radiusOf(tester, find.byType(AppBadge)), BorderRadius.circular(AppRadius.pill));
  });
}
