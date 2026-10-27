@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../support/pressed_frame.dart';

/// What [AppCard] does under a finger.
///
/// The golden next door renders one resting frame of each variant and says nothing about what happens when the card is
/// touched, which is how a card whose every interaction state came from `MouseRegion` passed every check in this
/// repository while being inert on the only devices the app ships to (#367).
void main() {
  Widget card({required AppCardVariant variant, VoidCallback? onTap}) =>
      AppCard(variant: variant, onTap: onTap, child: const Text('Card body'));

  group('a card the user can tap', () {
    // The control. It proves the measurement can see a pressed state at all, so a failure below is a statement about
    // AppCard rather than about the helper.
    testWidgets('a plain InkWell — the control — draws a different frame while held', (tester) async {
      final pressed = await rendersPressedState(
        tester,
        Material(
          child: InkWell(onTap: () {}, child: const SizedBox.expand()),
        ),
      );
      expect(pressed, isTrue, reason: 'the measurement itself is broken if a bare InkWell shows nothing');
    });

    for (final variant in AppCardVariant.values) {
      testWidgets('draws a different frame while held — ${variant.name}', (tester) async {
        final pressed = await rendersPressedState(tester, card(variant: variant, onTap: () {}));
        expect(pressed, isTrue, reason: 'a ${variant.name} card with an onTap answers a finger with nothing');
      });
    }
  });

  // The pixels above say the card answers, but an ink splash alone would satisfy them, and the splash belongs to the
  // InkWell rather than to the card. What #367 was actually about is the card's own design — the lift of `elevated`,
  // the border of `outlined`, the fill of `filled` — being reachable without a mouse, so that is asserted on its own.
  group('the card carries its variant into the press', () {
    for (final variant in AppCardVariant.values) {
      testWidgets('its decoration changes while held — ${variant.name}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 120,
                  child: card(variant: variant, onTap: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Decoration? decoration() => tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration;
        final resting = decoration();

        final gesture = await tester.startGesture(tester.getCenter(find.byType(AnimatedContainer)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final pressed = decoration();

        await gesture.up();
        await tester.pumpAndSettle();

        expect(pressed, isNot(resting), reason: 'a held ${variant.name} card still looks exactly like a resting one');
      });
    }
  });

  // directory_picker_view.dart:240 passes `onTap: user.enabled ? ... : null`, so a reload that brings a held row back
  // disabled takes the InkWell out from under the finger. InkResponse.deactivate disposes its highlights without
  // going through updateHighlight, so onHighlightChanged never fires and the card would stay engaged forever (#367).
  testWidgets('a card that stops being tappable while held does not stay engaged', (tester) async {
    Future<void> pump({required bool tappable}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 120,
              child: card(variant: AppCardVariant.outlined, onTap: tappable ? () {} : null),
            ),
          ),
        ),
      ),
    );

    await pump(tappable: true);
    await tester.pumpAndSettle();
    Decoration? decoration() => tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration;
    final resting = decoration();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(AnimatedContainer)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(decoration(), isNot(resting), reason: 'the card has to be engaged before the onTap is taken away');

    await pump(tappable: false);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(decoration(), resting, reason: 'the card stayed engaged with nothing left to press');
  });

  // `outlineVariant` is Material 3's decorative divider, which the non-text contrast rule exempts; `outline` is the
  // token for the edge of a component, which it does not. A card's border is the second thing, and using the first
  // left it below the floor even after the palettes were corrected (#369).
  testWidgets('an outlined card draws its edge with the boundary colour, not the divider one', (tester) async {
    late ColorScheme scheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: Center(
                child: SizedBox(width: 300, height: 120, child: card(variant: AppCardVariant.outlined)),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final decoration = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration;
    expect(decoration.border, Border.all(color: scheme.outline));
  });

  group('a card the user cannot tap', () {
    for (final variant in AppCardVariant.values) {
      testWidgets('stays inert while held — ${variant.name}', (tester) async {
        final pressed = await rendersPressedState(tester, card(variant: variant));
        expect(pressed, isFalse, reason: 'a card with no onTap must not look tappable');
      });
    }
  });

  // Clipping the splash with a shape on the card's Material also clipped its hit test, and a corner that no longer
  // answers is a tap target quietly shrunk on eight screens. The splash is clipped by the InkWell's own radius
  // instead, and this is what says so (#367).
  testWidgets('the whole card takes the tap, corners included', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 120,
              child: card(variant: AppCardVariant.outlined, onTap: () => taps++),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card_ = tester.getRect(find.byType(AppCard));
    for (final corner in [card_.topLeft, card_.topRight, card_.bottomLeft, card_.bottomRight]) {
      taps = 0;
      await tester.tapAt(corner + Offset(corner.dx == card_.left ? 3 : -3, corner.dy == card_.top ? 3 : -3));
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'the corner at $corner does not take a tap');
    }
  });

  testWidgets('the tap still reaches the caller', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: card(variant: AppCardVariant.outlined, onTap: () => taps++),
        ),
      ),
    );
    await tester.tap(find.text('Card body'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
