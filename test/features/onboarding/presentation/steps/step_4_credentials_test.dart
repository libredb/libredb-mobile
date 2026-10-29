@Tags(['widget'])
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_4_credentials.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

/// How far past the left or right edge of its own box the screen draws, on the frame now on screen, in logical
/// pixels. Zero when every box of the hero is inside it.
///
/// This is measured off the laid-out boxes rather than read off Flutter's overflow stripe, because the stripe is a
/// debug-paint artefact of `RenderFlex` alone: a `Positioned`, an `Align` or a `Transform` that puts something
/// outside the hero draws no stripe and throws nothing. The hero's own box is the reference, so the measurement does
/// not depend on where the chassis puts it.
double _drawsOutsideItsBox(WidgetTester tester) {
  final hero = tester.renderObject<RenderBox>(find.byType(Step4Credentials));
  var worst = 0.0;
  void measure(RenderObject node) {
    if (node is RenderBox && node.hasSize) {
      final box = MatrixUtils.transformRect(node.getTransformTo(hero), Offset.zero & node.size);
      worst = max(worst, max(box.right - hero.size.width, -box.left));
    }
    node.visitChildren(measure);
  }

  measure(hero);
  return worst;
}

/// The fourth screen's hero: this app, Studio and the database on one wire, the padlock shutting on Studio, and rows
/// coming back up.
///
/// What is settled here is the claim the screen makes. The padlock is open until its own beat and shut after it, and
/// the token that carries `seed:7` never leaves the wire between the app and Studio — the drawing says the request
/// stops at Studio, so the drawing is what is measured, not the caption.
void main() {
  /// The whole timeline and a little more, so a pump of this length lands on the finished screen.
  const past = Duration(seconds: 6);

  Future<void> show(
    WidgetTester tester, {
    bool animations = true,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    double heroWidth = 318,
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: !animations, textScaler: TextScaler.linear(textScale)),
            // The hero box the chassis gives a step scrolls, as the prototype's does, so a step that
            // grows past it is the ordinary case. What must not happen is an overflow.
            child: Scaffold(
              body: SingleChildScrollView(
                // The hero's own width, not the screen's: the chassis pads the panel 48 pt on the
                // leading edge and 24 on the trailing one, which leaves a step 318 pt on a 390 pt phone.
                // A step tested at the full screen width is tested 48 pt wider than it will ever be.
                child: SizedBox(width: heroWidth, child: const Step4Credentials()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  S l10n(WidgetTester tester) => S.of(tester.element(find.byType(Step4Credentials)));

  group('the padlock on Studio', () {
    testWidgets('is open on the frame before its beat and shut on the frame after it', (tester) async {
      await show(tester);
      await tester.pump(Step4Credentials.keyShutsAt - const Duration(milliseconds: 20));
      expect(find.byIcon(Icons.lock_open_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);

      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_outlined), findsNothing);
    });

    testWidgets('stays shut to the end', (tester) async {
      await show(tester);
      await tester.pump(past);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('what travels', () {
    testWidgets('the token carrying seed:7 never leaves the wire above Studio', (tester) async {
      await show(tester);
      final wire = find.byKey(Step4Credentials.upperWireKey);
      final token = find.byKey(Step4Credentials.requestTokenKey);
      var sawIt = false;
      for (var elapsed = Duration.zero; elapsed < past; elapsed += const Duration(milliseconds: 40)) {
        if (token.evaluate().isNotEmpty) {
          sawIt = true;
          final travelled = tester.getRect(token);
          final rails = tester.getRect(wire);
          expect(
            rails.inflate(1).contains(travelled.topLeft) && rails.inflate(1).contains(travelled.bottomRight),
            isTrue,
            reason: 'the request token was at $travelled, outside the upper wire $rails',
          );
        }
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(sawIt, isTrue, reason: 'the request token was never drawn');
    });

    testWidgets('the token moves down the wire rather than sitting still', (tester) async {
      await show(tester);
      await tester.pump(Step4Credentials.requestAt + const Duration(milliseconds: 80));
      final first = tester.getRect(find.byKey(Step4Credentials.requestTokenKey)).top;
      await tester.pump(const Duration(milliseconds: 200));
      final later = tester.getRect(find.byKey(Step4Credentials.requestTokenKey)).top;
      expect(later, greaterThan(first));
    });

    testWidgets('the closing note, that rows come back and the password does not, shows at the end', (tester) async {
      await show(tester);
      await tester.pump(Step4Credentials.rowsReturnAt - const Duration(milliseconds: 40));
      final s = l10n(tester);
      expect(tester.widget<Opacity>(find.byKey(Step4Credentials.closingNoteKey)).opacity, 0.0);

      await tester.pump(past);
      expect(tester.widget<Opacity>(find.byKey(Step4Credentials.closingNoteKey)).opacity, 1.0);
      expect(find.text(s.ob4_back), findsOneWidget);
    });
  });

  group('the screen itself', () {
    testWidgets('names all three nodes of the chain', (tester) async {
      await show(tester);
      await tester.pump(past);
      final s = l10n(tester);
      expect(find.text(s.ob4_app), findsOneWidget);
      expect(find.text(s.ob4_studio), findsOneWidget);
      expect(find.text(Step4Credentials.connectionName), findsOneWidget);
      expect(find.text(s.ob4_vault), findsOneWidget);
      expect(find.text(s.ob4_connects), findsOneWidget);
    });

    testWidgets('settles into the shut padlock and the note at once when animations are off', (tester) async {
      await show(tester, animations: false);
      await tester.pump();
      final s = l10n(tester);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_outlined), findsNothing);
      expect(tester.widget<Opacity>(find.byKey(Step4Credentials.closingNoteKey)).opacity, 1.0);
      expect(find.text(s.ob4_back), findsOneWidget);
    });

    testWidgets('lays out at every ordinary text scale without overflowing', (tester) async {
      for (final scale in [1.0, 1.5, 2.0, 3.0]) {
        await show(tester, textScale: scale);
        await tester.pump(past);
      }
    });

    testWidgets('holds nothing a finger can press', (tester) async {
      await show(tester);
      await tester.pump(past);
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('says the same thing in Turkish', (tester) async {
      await show(tester, locale: const Locale('tr'));
      await tester.pump(past);
      final s = l10n(tester);
      expect(find.text(s.ob4_app), findsOneWidget);
      expect(find.text(s.ob4_vault), findsOneWidget);
      expect(find.text(s.ob4_back), findsOneWidget);
    });
  });

  /// The chassis gives the hero a box that scrolls vertically, so a screen that grows taller than the slack is
  /// absorbed; what nothing absorbs is width. At an accessibility text size the words of this screen are two and
  /// three times as long, and every one of them has to fold inside the hero's own width instead of running out of
  /// it — which is what [_drawsOutsideItsBox] measures, frame by frame, rather than trusting the drawing.
  ///
  /// The widths are the ones the chassis actually hands a step on the devices `onboarding_page_test.dart` walks:
  /// the viewport less the 48 pt leading and 24 pt trailing gutter — 318 pt on a 390 pt phone, 248 pt on a 320 pt
  /// one, 772 pt turned sideways.
  group('the screen folds inside the width it is given', () {
    const heroWidths = <double>[318, 248, 772];
    const frame = Duration(milliseconds: 100);

    for (final scale in [1.3, 2.0, 3.0]) {
      testWidgets('draws nothing outside its own box at a text scale of $scale', (tester) async {
        for (final width in heroWidths) {
          for (final locale in [const Locale('en'), const Locale('tr')]) {
            await show(tester, textScale: scale, heroWidth: width, locale: locale);
            // Every frame of the timeline, not only the last: a token is mid-wire for most of it, and a label that
            // ran out of the hero would be back inside it by the time the screen settled.
            for (var at = Duration.zero; at < past; at += frame) {
              await tester.pump(frame);
              expect(
                _drawsOutsideItsBox(tester),
                lessThanOrEqualTo(0.0001),
                reason: 'at $width pt, a text scale of $scale, ${locale.languageCode}, ${at.inMilliseconds} ms in',
              );
            }
          }
        }
      });
    }
  });
}
