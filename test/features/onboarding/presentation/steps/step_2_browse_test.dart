@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_2_browse.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

/// The second screen of the introduction: the tree, the row counts, then a column closing over into a mask.
///
/// The mask is asserted twice — the clear address is on screen first, the mask is what is left at the end. Only the
/// pair proves a mask: a column that was masked from its first frame renders the same last frame, and the audit that
/// caught the prototype inventing a mask shape is the reason the mask text itself is spelled out here rather than
/// read back off the widget.
void main() {
  Future<void> show(WidgetTester tester, {bool disableAnimations = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
            child: const Scaffold(
              body: Center(child: SizedBox(width: 320, child: Step2Browse())),
            ),
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester, String key) => tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;

  S l10nOf(WidgetTester tester) => S.of(tester.element(find.byType(Step2Browse)));

  testWidgets('the tree unfolds and the three row counts count up to their values', (tester) async {
    await show(tester);
    await tester.pump();

    final l10n = l10nOf(tester);
    expect(find.text('public'), findsOneWidget);
    expect(find.text(l10n.ob2_tables(3)), findsOneWidget);
    expect(find.text(l10n.browse_object_rows(0, '0')), findsNWidgets(3), reason: 'every count starts at nothing');

    // Half way through the count-up each number is on its way and none has arrived.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text(l10n.browse_object_rows(128440, '128,440')), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(l10n.browse_object_rows(128440, '128,440')), findsOneWidget);
    expect(find.text(l10n.browse_object_rows(12901, '12,901')), findsOneWidget);
    expect(find.text(l10n.browse_object_rows(44512, '44,512')), findsOneWidget);
  });

  testWidgets('the tree leaves and the grid takes its place', (tester) async {
    await show(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('public'), findsOneWidget);
    expect(find.text('id'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('public'), findsNothing, reason: 'the tree has slid out');
    expect(find.text('id'), findsOneWidget);
    expect(find.text('email'), findsOneWidget);
    expect(find.text('total'), findsOneWidget);
  });

  testWidgets('the addresses arrive in the clear and then close over into the mask', (tester) async {
    await show(tester);

    // 2900 ms: the grid is in and the values are still the ones the engine answered with.
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.text('ayse@libredb.io'), findsOneWidget, reason: 'the clear value is what was shown first');
    expect(find.text('mert@libredb.io'), findsOneWidget);
    expect(find.text('onur@libredb.io'), findsOneWidget);
    expect(find.text('a***@l*********'), findsNothing);
    expect(opacityOf(tester, 'ob2-mask-lock'), 0.0, reason: 'no padlock while the column is in the clear');

    // The end: the mask is what is left, and the padlock stands beside the column.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('ayse@libredb.io'), findsNothing, reason: 'the clear value is gone');
    expect(find.text('mert@libredb.io'), findsNothing);
    expect(find.text('onur@libredb.io'), findsNothing);
    expect(find.text('a***@l*********'), findsOneWidget, reason: "Studio's own email mask keeps the length");
    expect(find.text('m***@l*********'), findsOneWidget);
    expect(find.text('o***@l*********'), findsOneWidget);
    expect(opacityOf(tester, 'ob2-mask-lock'), 1.0);

    expect(find.text('1249.00'), findsOneWidget, reason: 'an unmatched column is untouched');
    expect(find.text('8842'), findsOneWidget);
    expect(find.text(l10nOf(tester).ob2_why), findsOneWidget);
  });

  testWidgets('the value blurs while it closes over, and the blur clears once the mask is there', (tester) async {
    await show(tester);

    await tester.pump(const Duration(milliseconds: 3150));
    expect(find.byType(ImageFiltered), findsWidgets, reason: 'the column is closing over');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(ImageFiltered), findsNothing, reason: 'the mask is left readable');
  });

  testWidgets('with animations off it settles into its finished state on the first frame', (tester) async {
    await show(tester, disableAnimations: true);
    await tester.pump();

    expect(find.text('public'), findsNothing);
    expect(find.text('a***@l*********'), findsOneWidget);
    expect(find.text('ayse@libredb.io'), findsNothing);
    expect(opacityOf(tester, 'ob2-mask-lock'), 1.0);
    expect(opacityOf(tester, 'ob2-note'), 1.0);
    expect(find.text(l10nOf(tester).ob2_why), findsOneWidget);
  });

  testWidgets('nothing in the step is tappable', (tester) async {
    await show(tester, disableAnimations: true);
    await tester.pump();

    final step = find.byType(Step2Browse);
    expect(find.descendant(of: step, matching: find.byType(InkWell)), findsNothing);
    expect(find.descendant(of: step, matching: find.byType(GestureDetector)), findsNothing);
  });
}
