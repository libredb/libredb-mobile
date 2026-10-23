/// What a piece of a source line is, for its colour.
enum SourceTokenKind { plain, keyword, string, number, comment }

/// A piece of one source line.
class SourceToken {
  const SourceToken(this.text, this.kind);

  final String text;
  final SourceTokenKind kind;
}

/// Simple keyword highlighting of one line at a time, chosen by the language Studio names for a part.
///
/// It reads each line on its own, so a block comment or a string that spans lines is marked only on its first line;
/// that keeps a line's tokens cheap enough to compute while the line scrolls into view. A language it does not know
/// reads as plain text.
class SourceHighlighter {
  const SourceHighlighter._(this._rules, this._keywords, {this.ignoreCase = false});

  final List<(RegExp, SourceTokenKind)> _rules;
  final Set<String> _keywords;

  /// Whether a keyword matches in any case, as in SQL.
  final bool ignoreCase;

  static const _plainText = SourceHighlighter._([], {});

  /// The highlighter for [language], a Monaco language id such as `pgsql` or `json`.
  static SourceHighlighter forLanguage(String language) => switch (language) {
    _ when isSql(language) => _sql,
    'json' => _json,
    'lua' => _lua,
    'javascript' || 'typescript' => _javascript,
    _ => _plainText,
  };

  /// Whether [language] is a dialect of SQL.
  static bool isSql(String language) => const {'sql', 'pgsql', 'mysql', 'plsql', 'tsql', 'redshift'}.contains(language);

  static Set<String> _words(String words) => words.split(' ').toSet();

  static final _identifier = RegExp(r'[A-Za-z_][A-Za-z0-9_$]*');

  /// The tokens of [line], which put together are [line].
  List<SourceToken> tokens(String line) {
    if (line.isEmpty) return const [];
    if (_rules.isEmpty) return [SourceToken(line, SourceTokenKind.plain)];
    final tokens = <SourceToken>[];
    final plain = StringBuffer();
    void flush() {
      if (plain.isEmpty) return;
      tokens.add(SourceToken(plain.toString(), SourceTokenKind.plain));
      plain.clear();
    }

    var index = 0;
    scan:
    while (index < line.length) {
      for (final (pattern, kind) in _rules) {
        final match = pattern.matchAsPrefix(line, index);
        if (match == null || match.end == index) continue;
        final text = match[0]!;
        if (kind == SourceTokenKind.plain) {
          plain.write(text);
        } else {
          flush();
          tokens.add(SourceToken(text, kind));
        }
        index = match.end;
        continue scan;
      }
      final word = _identifier.matchAsPrefix(line, index);
      if (word != null) {
        final text = word[0]!;
        if (_keywords.contains(ignoreCase ? text.toUpperCase() : text)) {
          flush();
          tokens.add(SourceToken(text, SourceTokenKind.keyword));
        } else {
          plain.write(text);
        }
        index = word.end;
        continue;
      }
      plain.write(line[index]);
      index++;
    }
    flush();
    return tokens;
  }

  static final _blockComment = RegExp(r'/\*.*?(\*/|$)');
  static final _number = RegExp(r'\d+(\.\d+)?\b');

  static final _sql = SourceHighlighter._(
    [
      (RegExp(r'--.*'), SourceTokenKind.comment),
      (_blockComment, SourceTokenKind.comment),
      (RegExp(r"'(?:[^']|'')*'?"), SourceTokenKind.string),
      // A quoted name is a name, so a keyword inside it stays plain.
      (RegExp(r'"[^"]*"?|`[^`]*`?|\[[^\]]*\]?'), SourceTokenKind.plain),
      (_number, SourceTokenKind.number),
    ],
    _words(
      'ADD ALL ALTER AND ANY AS ASC BEGIN BETWEEN BODY BY CASCADE CASE CAST CHECK COALESCE COLUMN '
      'COMMIT CONSTRAINT CREATE CROSS CURSOR DECLARE DEFAULT DELETE DESC DISTINCT DO DROP EACH ELSE '
      'ELSIF END EXCEPTION EXECUTE EXISTS FALSE FETCH FOR FOREIGN FROM FULL FUNCTION GRANT GROUP HAVING '
      'IF IMMUTABLE IN INDEX INNER INSERT INTO IS JOIN KEY LANGUAGE LEFT LIKE LIMIT LOOP NOT NULL OF '
      'OFFSET ON OR ORDER OUTER PACKAGE PRIMARY PROCEDURE REFERENCES REPLACE RETURN RETURNS RIGHT '
      'ROLLBACK ROW SELECT SET STABLE TABLE THEN TO TRIGGER TRUE UNION UNIQUE UPDATE USING VALUES VIEW '
      'VOLATILE WHEN WHERE WHILE WITH',
    ),
    ignoreCase: true,
  );

  static final _json = SourceHighlighter._([
    (RegExp(r'"(?:[^"\\]|\\.)*"?'), SourceTokenKind.string),
    (RegExp(r'-?\d+(\.\d+)?([eE][+-]?\d+)?'), SourceTokenKind.number),
  ], _words('true false null'));

  static final _lua = SourceHighlighter._(
    [
      (RegExp(r'--.*'), SourceTokenKind.comment),
      (RegExp(r'"(?:[^"\\]|\\.)*"?'), SourceTokenKind.string),
      (RegExp(r"'(?:[^'\\]|\\.)*'?"), SourceTokenKind.string),
      (_number, SourceTokenKind.number),
    ],
    _words(
      'and break do else elseif end false for function goto if in local nil not or repeat return then '
      'true until while',
    ),
  );

  static final _javascript = SourceHighlighter._(
    [
      (RegExp(r'//.*'), SourceTokenKind.comment),
      (_blockComment, SourceTokenKind.comment),
      (RegExp(r'"(?:[^"\\]|\\.)*"?'), SourceTokenKind.string),
      (RegExp(r"'(?:[^'\\]|\\.)*'?"), SourceTokenKind.string),
      (RegExp(r'`(?:[^`\\]|\\.)*`?'), SourceTokenKind.string),
      (_number, SourceTokenKind.number),
    ],
    _words(
      'async await break case catch class const continue default do else export false for function if '
      'import in let new null of return switch this throw true try typeof undefined var while',
    ),
  );
}
