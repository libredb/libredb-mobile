import 'dart:math' as math;

import 'package:libredb_mobile/shared/security/result_masking/masking_config.dart';

// A port of Studio's mask functions (`MASK_FUNCTIONS`, `maskByType` and `maskValueByPattern` in
// `src/lib/data-masking.ts:157-243` at libredb-studio c9989a6b5), with three corrections of open Studio bugs named
// where they apply. String lengths and indexes are UTF-16 code units on both sides, so the two agree character for
// character.

/// [value] masked by [pattern]'s mask type (Studio's `maskByType`).
String maskByType(String value, MaskingPattern pattern) => switch (pattern.maskType) {
  MaskType.email => _email(value),
  MaskType.phone => _phone(value),
  MaskType.card => '****-****-****-${_lastFour(value.replaceAll(_nonDigit, '')).padLeft(4, '*')}',
  MaskType.ssn => '***-**-${_lastFour(value).padLeft(4, '*')}',
  MaskType.full => '********',
  MaskType.partial => _partial(value),
  MaskType.ip => _ip(value),
  MaskType.date => _date(value),
  MaskType.financial => '***,***.**',
  MaskType.custom => (pattern.customMask?.isNotEmpty ?? false) ? pattern.customMask! : '***',
};

/// `NULL` for a null value, else [value] masked as JavaScript's `String` prints it (Studio's `maskValueByPattern`).
String maskValueByPattern(Object? value, MaskingPattern pattern) =>
    value == null ? 'NULL' : maskByType(jsString(value), pattern);

/// [value], decoded from JSON, as JavaScript's `String(value)` prints it, which is what Studio masks: a map is
/// `[object Object]`, a list its elements joined with `,` (a null element as an empty string, as
/// `Array.prototype.join` writes it), and a number as JavaScript prints a double, so `85000.0` is `85000`. A document
/// is therefore never masked from its own text.
String jsString(Object? value) => switch (value) {
  null => 'null',
  String() => value,
  bool() => '$value',
  num() => _jsNumber(value),
  List() => value.map((element) => element == null ? '' : jsString(element)).join(','),
  _ => '[object Object]',
};

final _nonDigit = RegExp(r'\D');
final _calendarDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// JavaScript's shortest form of [number] as a double: Dart prints the same digits and exponents, but writes `.0` on a
/// whole number below 1e21 and keeps the sign of zero, which JavaScript does not.
String _jsNumber(num number) {
  final asDouble = number.toDouble();
  if (asDouble == 0) return '0';
  final text = asDouble.toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// The last four characters of [text], or all of it when it is shorter (JavaScript's `slice(-4)`).
String _lastFour(String text) => text.length > 4 ? text.substring(text.length - 4) : text;

String _email(String value) {
  final parts = value.split('@');
  // Studio prints `undefined` for an empty local part or domain (libredb/libredb-studio#1915); the port gives the
  // generic mask it already gives a malformed address.
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return '***@***.***';
  final [name, domain] = parts;
  return '${name[0]}${'*' * math.max(name.length - 1, 2)}@${domain[0]}${'*' * math.max(domain.length - 1, 2)}';
}

String _phone(String value) {
  final digits = value.replaceAll(_nonDigit, '');
  if (digits.length < 4) return '***';
  return '${'*' * (digits.length - 4)}${_lastFour(digits)}';
}

/// Up to 8 characters, all stars; from 9 on, `k = min(4, n ~/ 8)` characters at each end and stars between, so the
/// mask keeps the length and shows at most a quarter of the value. Studio shows four at each end of any value longer
/// than 8, which is 8 of 9 or 10 characters (libredb/libredb-studio#1915); the port keeps this rule until Studio merges
/// its own fix.
String _partial(String value) {
  final n = value.length;
  if (n <= 8) return '*' * n;
  final k = math.min(4, n ~/ 8);
  return '${value.substring(0, k)}${'*' * (n - 2 * k)}${value.substring(n - k)}';
}

String _ip(String value) {
  final parts = value.split('.');
  if (parts.length == 4) return '${parts[0]}.***.***.${parts[3]}';
  return '***';
}

/// A bare calendar date `YYYY-MM-DD` keeps its day, as in Studio; any other value is all stars. Studio keeps the last
/// two characters of any value, so a timestamp shows `****-**-0Z` (libredb/libredb-studio#1917); the port keeps this
/// rule until Studio merges its own fix.
String _date(String value) {
  if (_calendarDate.hasMatch(value)) return '****-**-${value.substring(value.length - 2)}';
  return '****-**-**';
}
