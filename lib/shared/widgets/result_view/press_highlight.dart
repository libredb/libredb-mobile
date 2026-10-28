import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Paints the theme's press highlight behind [child] for as long as a finger is on it.
///
/// A result row is an `InkWell` whose cells each carry an opaque long press, and the two compete for the same pointer.
/// Flutter's tap recognizer only reports the press once it wins the arena, which a pending long press holds open until
/// the finger lifts, so the row's ink draws **nothing** while it is held: the only answer a row ever gave was the
/// splash confirming on release, a flash after the fact. With the splash gone app-wide (#417) that answer was nothing
/// at all, measured at 0.0% of the row by `test/support/pressed_frame.dart` — the defect of #367 in a new place.
///
/// So the row paints the press itself, from the raw pointer stream, which no arena can hold back. The colour is
/// `ThemeData.highlightColor` — the same flat tint every other control in the app shows under a finger, kept clipped
/// to the row's own shape, never a circle growing out of the touch point.
///
/// The highlight is dropped when the finger travels more than [kTouchSlop], which is the pointer becoming a scroll
/// rather than a press: without that, flinging a result list would leave a lit row behind the finger.
class PressHighlight extends StatefulWidget {
  const PressHighlight({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// Whether a press is answered at all. False for a row with no `onTap`, because something that cannot be opened must
  /// not look as though it can.
  final bool enabled;

  @override
  State<PressHighlight> createState() => _PressHighlightState();
}

class _PressHighlightState extends State<PressHighlight> {
  /// The pointer being followed, so a second finger landing elsewhere neither re-lights nor clears the row.
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _pressed = false;

  @override
  void didUpdateWidget(PressHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A row can lose its tap under the finger — a reload that replaces the result keeps the pointer but takes the
    // handler away — and nothing in the pointer stream would ever clear a highlight left behind by that.
    if (!widget.enabled && _pressed) {
      _pointer = null;
      _pressed = false;
    }
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    _pointer = event.pointer;
    _origin = event.position;
    setState(() => _pressed = true);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer == _pointer && (event.position - _origin).distance > kTouchSlop) _clear(event);
  }

  void _clear(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _clear,
    onPointerCancel: _clear,
    child: ColoredBox(color: _pressed ? Theme.of(context).highlightColor : Colors.transparent, child: widget.child),
  );
}
