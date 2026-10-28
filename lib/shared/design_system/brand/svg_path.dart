import 'dart:ui';

/// The SVG path data [d] as a Flutter [Path].
///
/// It exists because the product's brand mark is an SVG and this app carries nothing that can render one. Adding a
/// renderer for a single shape is a dependency the app would pay for on every build and every upgrade; the shape is
/// one file, and the subset of the syntax it is written in is nine commands (#390).
///
/// Those nine are `M`/`m`, `L`/`l`, `H`/`h`, `V`/`v`, `C`/`c`, `S`/`s` and `Z`/`z`, measured from
/// `tool/design-system/assets/lb-icon.svg` rather than assumed. **Anything else throws.** A parser that quietly
/// skips an arc draws a mark that is subtly not the brand's, which is worse than one that refuses: the first ships,
/// the second is a red test.
///
/// Quadratics are among the ones it refuses. The mark has none, and guessing at one would be inventing geometry.
Path parseSvgPath(String d) {
  final tokens = _Tokens(d);
  final path = Path();

  // The pen, and the second control point of the last cubic — `S` reflects it, and the spec says an `S` that does
  // not follow a cubic reflects the current point onto itself, which is the same as using it directly.
  var current = Offset.zero;
  var start = Offset.zero;
  var lastControl = Offset.zero;
  var lastWasCubic = false;
  var hasMoved = false;
  String? command;

  Offset point(bool relative, double x, double y) => relative ? current + Offset(x, y) : Offset(x, y);

  while (tokens.hasMore) {
    final next = tokens.peekCommand();
    if (next != null) {
      command = next;
      tokens.takeCommand();
    } else if (command == null) {
      throw FormatException('a path has to begin with a move command: $d');
    } else if (command == 'M') {
      // "If a moveto is followed by multiple pairs of coordinates, the subsequent pairs are treated as implicit
      // lineto commands" — the spec, and the minifier uses it.
      command = 'L';
    } else if (command == 'm') {
      command = 'l';
    }

    if (!hasMoved && command.toUpperCase() != 'M') {
      // `Path` would treat a line before any move as starting at the origin, which silently draws a shape nobody
      // wrote.
      throw FormatException('a path has to begin with a move command: $d');
    }

    final relative = command == command.toLowerCase();
    switch (command.toUpperCase()) {
      case 'M':
        current = point(relative, tokens.number(), tokens.number());
        start = current;
        path.moveTo(current.dx, current.dy);
        hasMoved = true;
        lastWasCubic = false;
      case 'L':
        current = point(relative, tokens.number(), tokens.number());
        path.lineTo(current.dx, current.dy);
        lastWasCubic = false;
      case 'H':
        final x = tokens.number();
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
        lastWasCubic = false;
      case 'V':
        final y = tokens.number();
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
        lastWasCubic = false;
      case 'C':
        final first = point(relative, tokens.number(), tokens.number());
        final second = point(relative, tokens.number(), tokens.number());
        final end = point(relative, tokens.number(), tokens.number());
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        current = end;
        lastControl = second;
        lastWasCubic = true;
      case 'S':
        final first = lastWasCubic ? current * 2 - lastControl : current;
        final second = point(relative, tokens.number(), tokens.number());
        final end = point(relative, tokens.number(), tokens.number());
        path.cubicTo(first.dx, first.dy, second.dx, second.dy, end.dx, end.dy);
        current = end;
        lastControl = second;
        lastWasCubic = true;
      case 'Z':
        path.close();
        current = start;
        lastWasCubic = false;
      default:
        throw FormatException('this parser understands M L H V C S Z only, not "$command": $d');
    }
  }

  return path;
}

/// Reads the numbers and command letters of a path, in the minified form the mark is written in: `l-10,0` is a
/// command and two numbers, and `10-5` is two numbers with no separator between them.
class _Tokens {
  _Tokens(this._source);

  final String _source;
  int _at = 0;

  void _skipSeparators() {
    while (_at < _source.length && (_source[_at] == ' ' || _source[_at] == ',' || _source[_at] == '\n')) {
      _at++;
    }
  }

  bool get hasMore {
    _skipSeparators();
    return _at < _source.length;
  }

  /// The command letter at the cursor, or null when a number is next.
  String? peekCommand() {
    _skipSeparators();
    if (_at >= _source.length) return null;
    final character = _source[_at];
    return RegExp('[A-Za-z]').hasMatch(character) ? character : null;
  }

  void takeCommand() => _at++;

  double number() {
    _skipSeparators();
    final start = _at;
    if (_at < _source.length && (_source[_at] == '-' || _source[_at] == '+')) _at++;
    while (_at < _source.length && RegExp('[0-9.]').hasMatch(_source[_at])) {
      _at++;
    }
    if (_at == start) throw FormatException('expected a number at $start: $_source');
    return double.parse(_source.substring(start, _at));
  }
}
