@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_badge.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';

/// The shape of a badge, which is one shape across the app or it is noise.
///
/// `connection_badges.dart` drew its own at `circular(4)` while the design system's two badge components take
/// `AppRadius.pill`, so the same idea — a small label beside a connection — was a rounded rectangle on the Studio
/// side and a pill on the Platform side. The class is even called `_Pill` (#375).
void main() {
  Future<void> pump(WidgetTester tester, Widget subject) async {
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
        home: Scaffold(body: Center(child: subject)),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('and that is the same shape AppBadge draws', (tester) async {
    await pump(tester, const AppBadge(label: 'x'));
    expect(radiusOf(tester, find.byType(AppBadge)), BorderRadius.circular(AppRadius.pill));
  });
}
