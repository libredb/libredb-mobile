import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/utils/source_highlighter.dart';

void main() {
  List<(String, SourceTokenKind)> tokens(String language, String line) => [
    for (final token in SourceHighlighter.forLanguage(language).tokens(line)) (token.text, token.kind),
  ];

  const plain = SourceTokenKind.plain;
  const keyword = SourceTokenKind.keyword;
  const string = SourceTokenKind.string;
  const number = SourceTokenKind.number;
  const comment = SourceTokenKind.comment;

  group('SQL', () {
    test('marks keywords in any case, strings, numbers and a line comment', () {
      expect(tokens('pgsql', "select id FROM t WHERE s = 'from' AND n > 10 -- the open ones"), [
        ('select', keyword),
        (' id ', plain),
        ('FROM', keyword),
        (' t ', plain),
        ('WHERE', keyword),
        (' s = ', plain),
        ("'from'", string),
        (' ', plain),
        ('AND', keyword),
        (' n > ', plain),
        ('10', number),
        (' ', plain),
        ('-- the open ones', comment),
      ]);
    });

    test('leaves a keyword inside a quoted name or another word alone', () {
      expect(tokens('sql', 'SELECT "select", selected, t1'), [('SELECT', keyword), (' "select", selected, t1', plain)]);
    });

    test('marks a block comment and a string that runs to the end of the line', () {
      expect(tokens('mysql', "/* note */ SET x = 'open"), [
        ('/* note */', comment),
        (' ', plain),
        ('SET', keyword),
        (' x = ', plain),
        ("'open", string),
      ]);
    });

    test('applies to every SQL dialect Studio names', () {
      for (final language in ['sql', 'pgsql', 'mysql', 'plsql', 'tsql', 'redshift']) {
        expect(tokens(language, 'BEGIN'), [('BEGIN', keyword)], reason: language);
      }
    });
  });

  test('JSON marks strings, numbers and its literals', () {
    expect(tokens('json', '  "orders": 12, "vip": true, "note": null, "x": -1.5e3'), [
      ('  ', plain),
      ('"orders"', string),
      (': ', plain),
      ('12', number),
      (', ', plain),
      ('"vip"', string),
      (': ', plain),
      ('true', keyword),
      (', ', plain),
      ('"note"', string),
      (': ', plain),
      ('null', keyword),
      (', ', plain),
      ('"x"', string),
      (': ', plain),
      ('-1.5e3', number),
    ]);
  });

  test('a JSON string keeps an escaped quote inside it', () {
    expect(tokens('json', r'"a \"b\" c"'), [(r'"a \"b\" c"', string)]);
  });

  test('Lua marks keywords, strings and a comment', () {
    expect(tokens('lua', "local function f() return 'x' end -- done"), [
      ('local', keyword),
      (' ', plain),
      ('function', keyword),
      (' f() ', plain),
      ('return', keyword),
      (' ', plain),
      ("'x'", string),
      (' ', plain),
      ('end', keyword),
      (' ', plain),
      ('-- done', comment),
    ]);
  });

  test('JavaScript marks keywords, a template string and a comment', () {
    expect(tokens('javascript', 'const a = `x`; // y'), [
      ('const', keyword),
      (' a = ', plain),
      ('`x`', string),
      ('; ', plain),
      ('// y', comment),
    ]);
  });

  test('a language with no highlighting, or one the app does not know, is one plain token', () {
    for (final language in ['plaintext', 'yaml', 'xml', 'cypher']) {
      expect(tokens(language, 'SELECT "x" 1'), [('SELECT "x" 1', plain)], reason: language);
    }
  });

  test('an empty line has no tokens', () {
    expect(tokens('sql', ''), isEmpty);
  });

  test('the tokens of a line put together are the line', () {
    const line = "CREATE OR REPLACE FUNCTION f(n bigint) RETURNS numeric AS \$\$ SELECT 'a''b' \$\$;";
    expect(SourceHighlighter.forLanguage('pgsql').tokens(line).map((t) => t.text).join(), line);
  });
}
