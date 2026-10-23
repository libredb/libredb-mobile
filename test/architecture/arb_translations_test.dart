import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that every message in `lib/l10n/intl_en.arb` has a Turkish translation in `intl_tr.arb` that uses the same
/// placeholders.
///
/// intl_utils generates `S` from the English file and looks each message up by name in the Turkish one, so a message
/// missing from `intl_tr.arb` still compiles and the Turkish app shows it in English without any error. A Turkish
/// message that leaves out a placeholder drops that value from the text.
///
/// It also guards that no ARB file under `lib/l10n` holds a key twice. A JSON reader, intl_utils included, keeps the
/// last copy, so a key repeated by a rebase passes `scripts/generate_l10n.sh` without a diff and can hide a stale
/// translation.
void main() {
  Map<String, dynamic> read(String locale) =>
      jsonDecode(File('lib/l10n/intl_$locale.arb').readAsStringSync()) as Map<String, dynamic>;
  Set<String> messages(Map<String, dynamic> arb) => {
    for (final key in arb.keys)
      if (!key.startsWith('@')) key,
  };

  final en = read('en');
  final tr = read('tr');

  test('intl_en.arb and intl_tr.arb have the same messages', () {
    expect(messages(en).difference(messages(tr)), isEmpty, reason: 'these English messages have no Turkish one');
    expect(messages(tr).difference(messages(en)), isEmpty, reason: 'these Turkish messages have no English one');
  });

  test('each Turkish message uses every placeholder that its English message declares', () {
    final missing = [
      for (final key in messages(en).intersection(messages(tr)))
        for (final name
            in ((en['@$key'] as Map<String, dynamic>?)?['placeholders'] as Map<String, dynamic>?)?.keys ??
                const <String>[])
          if (!RegExp('\\{$name[,}]').hasMatch(tr[key] as String)) '$key: {$name}',
    ];
    expect(missing, isEmpty, reason: 'these Turkish messages leave out a placeholder');
  });

  test('the repeated key check names the file and each key it holds twice', () {
    expect(repeatedArbKeys([File('test/fixtures/l10n/repeated_key.arb')]), [
      'test/fixtures/l10n/repeated_key.arb: @sql_history_replace',
      'test/fixtures/l10n/repeated_key.arb: @sql_history_replace.placeholders.count',
    ]);
  });

  test('no ARB file under lib/l10n holds a key twice', () {
    final files = Directory('lib/l10n').listSync().whereType<File>().where((file) => file.path.endsWith('.arb'));
    expect(files, isNotEmpty);
    expect(
      repeatedArbKeys(files),
      isEmpty,
      reason: 'these ARB keys appear twice; keep one copy and rerun scripts/generate_l10n.sh',
    );
  });
}

/// Returns `<file path>: <key path>` for each key that an object in one of [files] holds more than once, in the order
/// the repeated copies appear. A key path joins the keys from the top with dots, such as
/// `@sql_history_replace.placeholders.count`.
List<String> repeatedArbKeys(Iterable<File> files) => [
  for (final file in files)
    for (final key in _repeatedKeys(file.readAsStringSync())) '${file.path}: $key',
];

/// Walks well-formed JSON [source] and returns the path of every key that repeats one before it in the same object.
/// `jsonDecode` keeps the last copy without a word, so it serves only to reject malformed input first.
List<String> _repeatedKeys(String source) {
  jsonDecode(source);
  final repeated = <String>[];
  var i = 0;

  void skipSpace() {
    while (i < source.length && ' \t\n\r'.contains(source[i])) {
      i++;
    }
  }

  String readString() {
    final start = i++;
    while (source[i] != '"') {
      i += source[i] == r'\' ? 2 : 1;
    }
    i++;
    return jsonDecode(source.substring(start, i)) as String;
  }

  void readValue(String path) {
    skipSpace();
    final open = source[i];
    if (open == '"') {
      readString();
    } else if (open == '{' || open == '[') {
      final close = open == '{' ? '}' : ']';
      final seen = <String>{};
      var index = 0;
      i++;
      skipSpace();
      while (source[i] != close) {
        var childPath = '$path.${index++}';
        if (open == '{') {
          final key = readString();
          childPath = path.isEmpty ? key : '$path.$key';
          if (!seen.add(key)) repeated.add(childPath);
          skipSpace();
          i++; // the colon
        }
        readValue(childPath);
        skipSpace();
        if (source[i] == ',') i++;
        skipSpace();
      }
      i++;
    } else {
      while (i < source.length && !',}] \t\n\r'.contains(source[i])) {
        i++;
      }
    }
  }

  readValue('');
  return repeated;
}
