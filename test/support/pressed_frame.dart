import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

/// Renders [subject] and answers whether it draws a different frame while a finger is held on it.
///
/// This is the one thing the rest of the suite cannot see. A golden renders a single resting frame, the contrast and
/// tap-target guards read colours and sizes, and a `tap()` in a widget test only proves the callback ran. None of them
/// presses a widget and looks at what changed, which is how an app whose whole interaction state came from
/// `MouseRegion` stayed green while answering a finger with nothing (#367).
///
/// The two frames are compared against each other inside one test, never against a stored image, so this says the same
/// thing on a developer's machine as it does on CI — unlike a golden, which this repository can only generate there.
///
/// By default only the **held** frame counts, and that strictness is the point: the release runs the control's own
/// `onTap`, so a control that changes because its handler fired would pass while answering the finger with nothing.
/// Letting the release count once cost this suite a real failure — the warnings chip's `onTap` collapses the warning
/// list inside the captured area, so its test went green against the very defect it was written to pin.
///
/// [measureOnRelease] is the documented exception, for a subject whose tap competes in the gesture arena with a
/// `Scrollable`'s drag or a cell's long press: those keep the arena open, and an `InkWell` under an opaque long-press
/// detector draws nothing at all while held and 53,587 changed bytes the moment the finger lifts. A caller that sets
/// it passes an `onTap` that does nothing, so the frame can only have changed because of the touch.
///
/// [settle] is how long the press is held before the held frame is taken: long enough for a ripple to have grown and
/// for an implicit animation to have moved, short enough to stay inside a test.
Future<bool> rendersPressedState(
  WidgetTester tester,
  Widget subject, {
  Duration settle = const Duration(milliseconds: 300),
  Size surface = const Size(400, 300),
  Finder? pressAt,
  bool measureOnRelease = false,
}) async =>
    await pressedFractionOfControl(
      tester,
      subject,
      settle: settle,
      surface: surface,
      pressAt: pressAt,
      measureOnRelease: measureOnRelease,
    ) >=
    visiblePressFraction;

/// How much of a control has to change for the answer to count as one a person would see.
///
/// Not "any pixel": the warnings chip's defect leaked 50 pixels — 1.7% of the chip — through the corners its own
/// rounded background does not cover, while the ripple that matters stayed hidden underneath. A control that answers
/// a finger lights up, so the bar is a share of its own area rather than a single byte.
const visiblePressFraction = 0.05;

/// The share of the pressed control's own area that changes when it is pressed, between 0 and 1.
Future<double> pressedFractionOfControl(
  WidgetTester tester,
  Widget subject, {
  Duration settle = const Duration(milliseconds: 300),
  Size surface = const Size(400, 300),
  Finder? pressAt,
  bool measureOnRelease = false,
}) async {
  final frames = await pressedAndRestingFrames(tester, subject, settle: settle, surface: surface, pressAt: pressAt);
  final answered = measureOnRelease ? frames.released : frames.pressed;
  final control = frames.control;
  if (control.isEmpty) return 0;

  var changed = 0;
  for (var y = control.top.floor(); y < control.bottom.ceil(); y++) {
    for (var x = control.left.floor(); x < control.right.ceil(); x++) {
      final at = (y * frames.width + x) * 4;
      if (at < 0 || at + 4 > answered.length) continue;
      for (var channel = 0; channel < 4; channel++) {
        if (frames.resting[at + channel] != answered[at + channel]) {
          changed++;
          break;
        }
      }
    }
  }
  return changed / (control.width * control.height);
}

/// The raw pixels [subject] draws at rest and while held, for a caller that wants to say more about the difference
/// than whether there is one.
///
/// [pressAt] is where the finger goes when the middle of the surface is not the control. The centre of the subject
/// by default.
Future<({Uint8List resting, Uint8List pressed, Uint8List released, Rect control, int width})> pressedAndRestingFrames(
  WidgetTester tester,
  Widget subject, {
  Duration settle = const Duration(milliseconds: 300),
  Size surface = const Size(400, 300),
  Finder? pressAt,
}) async {
  const key = ValueKey('pressed-frame-boundary');
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
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            // The ink canvas has to be inside the boundary. A splash paints on the nearest `Material`, so with only
            // the Scaffold's to land on it would be drawn outside the captured region and every subject would look
            // inert — a verdict about the measurement rather than about the widget.
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(width: surface.width, height: surface.height, child: subject),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final resting = await _frame(tester, key);

  // Where the control sits inside the captured image, so the answer is measured over the control rather than over the
  // whole surface: a change that covers a fifth of a small chip is lost in a fraction of a large one.
  final target = pressAt ?? find.byKey(key);
  final boundary = tester.getRect(find.byKey(key));
  final control = tester.getRect(target).shift(-boundary.topLeft).intersect(Offset.zero & boundary.size);

  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump();
  await tester.pump(settle);
  final pressed = await _frame(tester, key);

  // And the frame just after the finger lifts, which is where a control under a competing recognizer finally answers.
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 80));
  final released = await _frame(tester, key);

  await tester.pumpAndSettle();

  return (resting: resting, pressed: pressed, released: released, control: control, width: boundary.width.round());
}

/// The pixels inside [key] right now.
///
/// Both calls are real asynchronous work, and a widget test runs on a fake clock that never drives it, so both are
/// awaited through [WidgetTester.runAsync] — without that they simply never return and the test dies on its timeout
/// rather than on its assertion.
///
/// `toImage`, not `toImageSync`: the synchronous form composites the layers already retained, so anything drawn
/// inside a nested repaint boundary — every child of a `ListView`, among others — can come back from the previous
/// raster, leaving the subject looking unchanged however it was pressed.
Future<Uint8List> _frame(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final data = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes;
  });
  return data!.buffer.asUint8List();
}
