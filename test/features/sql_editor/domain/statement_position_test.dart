import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/sql_editor/domain/statement_position.dart';

void main() {
  test('the first character is offset 0', () => expect(statementOffsetOf('SELEC 1', 1), 0));

  test(
    'a position inside plain text is the character before it',
    () => expect(statementOffsetOf('SELECT * FORM t', 10), 9),
  );

  test('a character outside the basic plane counts once in the position and twice in the offset', () {
    const text = "SELECT '😀', FORM t";
    final offset = statementOffsetOf(text, 13);

    expect(offset, 13);
    expect(text.substring(offset, offset + 4), 'FORM');
  });

  test('a position past the end lands at the end', () => expect(statementOffsetOf('SELECT', 99), 6));

  test('a position of the empty text is 0', () => expect(statementOffsetOf('', 3), 0));
}
