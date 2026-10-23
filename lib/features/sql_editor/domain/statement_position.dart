/// The UTF-16 offset in [text] of the database's error [position], which counts characters (code points) from 1 as
/// PostgreSQL reports it, clamped to the text: a position past the end lands at the end.
///
/// A Dart string counts UTF-16 code units, so a character outside the basic plane, such as an emoji, takes two of
/// them and moves every later offset by one.
int statementOffsetOf(String text, int position) {
  var offset = 0;
  var characters = 0;
  final runes = text.runes.iterator;
  while (characters < position - 1 && runes.moveNext()) {
    offset += runes.current > 0xFFFF ? 2 : 1;
    characters++;
  }
  return offset.clamp(0, text.length);
}
