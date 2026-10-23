import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';

/// One result value as Studio's grid renders it (libredb-studio `src/components/results-grid/renderers/`), classified
/// by the value's shape and never by the engine that produced it.
///
/// [compactText] is the one-line form of a grid cell, [detailText] the form of the row detail, and [copyText] what a
/// copy of the field writes, by the row detail sheet's rule (`copyTextOf`, `RowDetailSheet.tsx`): the renderer's copy
/// form where it has one (binary and vector), else the detail text. The phone keeps that rule for the cell copy too.
sealed class CellValue {
  const CellValue();

  String get compactText;
  String get detailText;
  String get copyText => detailText;
}

/// No value: `NULL` in a cell. The detail and the copy write `null` for a JSON null and `NULL` for a field the row
/// lacks, as Studio's sheet splits null from undefined (`renderers/null.ts`).
final class NullCell extends CellValue {
  const NullCell({this.isAbsent = false});

  /// The row carries no such field, as a document without it.
  final bool isAbsent;

  @override
  String get compactText => 'NULL';

  @override
  String get detailText => isAbsent ? 'NULL' : 'null';
}

/// A string, number or boolean, as Studio's scalar renderer prints it: a string exactly as it came, a number as
/// JavaScript's `String` prints it, a boolean as its word.
final class ScalarCell extends CellValue {
  const ScalarCell(this.text);

  final String text;

  @override
  String get compactText => text;

  @override
  String get detailText => text;
}

/// An object or array, or a string that parses to one.
///
/// In a cell, a string keeps its raw text and an object is compact JSON. In the detail, an object is pretty-printed
/// with two spaces; a string is pretty-printed only when its round trip is lossless, otherwise its stored text is kept
/// as it came (`renderers/json.ts`).
///
/// The round trip is Dart's own `jsonEncode` of its `jsonDecode`, which differs from JavaScript's in both directions,
/// though no digit is lost either way. Dart writes `1.0` and `-0.0` where JavaScript writes `1` and `0`, so a stored
/// `{"a":1.0}` or `[-0.0]` is pretty-printed here while Studio keeps its stored text. Dart keeps an integer past 2^53
/// exact where JavaScript rounds it, and a number past the double range reads as an infinity that JavaScript writes as
/// `null`; both count as lossy here, so the stored text is kept, as in Studio.
final class JsonCell extends CellValue {
  JsonCell._(this._value);

  final Object? _value;

  @override
  late final String compactText = switch (_value) {
    final String text => text,
    final value => _JsJson.stringify(value),
  };

  @override
  late final String detailText = switch (_value) {
    final String text => _storedDetail(text),
    final value => _JsJson.stringify(value, indent: '  '),
  };

  static String _storedDetail(String text) {
    // The classifier parsed the trimmed text, which JSON's own grammar may refuse untrimmed; the stored text then
    // keeps its padding and so never compares equal below.
    final parsed = jsonDecode(text.trim());
    // The number test comes first: `jsonEncode` throws on an infinity.
    if (!_holdsLossyNumber(parsed) && _stripJsonWhitespace(text) == jsonEncode(parsed)) {
      return const JsonEncoder.withIndent('  ').convert(parsed);
    }
    return text;
  }
}

/// A binary value, `{type: "Buffer", data: [bytes]}` on the wire: lowercase hex behind `\x`.
///
/// [preview] is the whole text up to 32 bytes, else the first 32 bytes and the size; the detail and the copy are the
/// whole value (`src/lib/export/binary.ts`, `renderers/binary.ts`).
final class BinaryCell extends CellValue {
  BinaryCell._(this.bytes);

  static const _previewBytes = 32;

  final Uint8List bytes;

  /// The cell's text.
  late final String preview = bytes.length <= _previewBytes
      ? _hex(bytes)
      : '${_hex(Uint8List.sublistView(bytes, 0, _previewBytes))}... ($size)';

  /// The byte count in B, KB or MB, as Studio's preview writes it.
  String get size {
    final length = bytes.length;
    if (length >= 1024 * 1024) return '${(length / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (length >= 1024) return '${(length / 1024).toStringAsFixed(1)} KB';
    return '$length B';
  }

  @override
  String get compactText => preview;

  @override
  late final String detailText = _hex(bytes);

  static String _hex(Uint8List bytes) {
    final hex = StringBuffer(r'\x');
    for (final byte in bytes) {
      hex.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return hex.toString();
  }
}

/// A cell of a declared vector column that has the column's shape (`renderers/vector.ts`).
///
/// The cell shows [preview] (the first 8 elements) and [size]; the detail is a header line over [copy], and [copy] is
/// the whole value as compact JSON in the engine's own encoding, a float element always with a fraction. [copy] is built
/// only when asked for, so a 1536-element cell never builds it to show a cell.
final class VectorCell extends CellValue {
  VectorCell._(this._cell, this._column);

  static const _previewElements = 8;
  static const _ellipsis = '…';

  final _VectorShape _cell;
  final VectorColumn _column;
  bool _copyBuilt = false;

  /// Whether [copy] has been built, for the test that a cell never builds it.
  @visibleForTesting
  bool get isCopyBuilt => _copyBuilt;

  late final String preview = _previewText();

  /// The size the cell holds, never the declared dimension in its place.
  late final String size = _sizeText();

  late final String copy = _buildCopy();

  @override
  String get compactText => '$preview $size';

  @override
  String get detailText => '${_column.kind} ${_column.dtype}, $size\n$copy';

  @override
  String get copyText => copy;

  String Function(num?) get _elementText =>
      _column.kind == 'multi' || _floatTypes.contains(_column.dtype) ? _floatText : _integerText;

  static const _floatTypes = {'float32', 'float64', 'float16', 'bfloat16'};

  String _previewText() {
    final text = _elementText;
    return switch (_cell) {
      _Dense(:final values) => '[${_head(values, text)}]',
      _Multi(:final rows) when rows.isEmpty => '[]',
      _Multi(:final rows) => '[[${_head(rows.first, text)}]${rows.length > 1 ? ', $_ellipsis' : ''}]',
      _Sparse(:final sortedIndices, :final sortedValues) => _sparsePreview(sortedIndices, sortedValues, text),
    };
  }

  String _sizeText() => switch (_cell) {
    _Dense(:final values) when _column.dtype == 'binary' => _counted(values.length * 8, 'bit', 'bits'),
    _Dense(:final values) => _counted(values.length, 'dim', 'dims'),
    _Multi(:final rows) =>
      '${_counted(rows.length, 'row', 'rows')} of '
          '${_counted(rows.isEmpty ? (_column.dimension ?? 0) : rows.first.length, 'dim', 'dims')}',
    _Sparse(:final sortedIndices) => _counted(sortedIndices.length, 'entry', 'entries'),
  };

  String _buildCopy() {
    _copyBuilt = true;
    final text = _elementText;
    return switch (_cell) {
      _Dense(:final values) => '[${values.map(text).join(',')}]',
      _Multi(:final rows) => '[${rows.map((row) => '[${row.map(text).join(',')}]').join(',')}]',
      _IndexMap(:final entries) => '{${entries.map((entry) => '${jsonEncode(entry.$1)}:${text(entry.$2)}').join(',')}}',
      _IndicesValues(:final indices, :final values) =>
        '{"indices":[${indices.map(_integerText).join(',')}],"values":[${values.map(text).join(',')}]}',
    };
  }

  static String _head(List<num?> items, String Function(num?) text) {
    final shown = [for (final item in items.take(_previewElements)) text(item)];
    if (items.length > _previewElements) shown.add(_ellipsis);
    return shown.join(', ');
  }

  static String _sparsePreview(List<num> indices, List<num> values, String Function(num?) text) {
    final pairs = [
      for (var position = 0; position < indices.length && position < _previewElements; position++)
        '${jsNumberText(indices[position])}: ${text(values[position])}',
    ];
    if (indices.length > _previewElements) pairs.add(_ellipsis);
    return '{${pairs.join(', ')}}';
  }

  static String _counted(int count, String one, String many) => '$count ${count == 1 ? one : many}';

  static String _floatText(num? element) {
    if (element == null) return 'null';
    if (element is double && element == 0 && element.isNegative) return '-0.0';
    final text = jsNumberText(element);
    // A fraction only where JavaScript writes none: `1e+21` is already a float.
    return _integral.hasMatch(text) ? '$text.0' : text;
  }

  static String _integerText(num? element) => element == null ? 'null' : jsNumberText(element);

  static final _integral = RegExp(r'^-?\d+$');
}

/// [value] classified as Studio's `classifyValue` does (`renderers/classify.ts`), in its order: no value, then a vector
/// (only where [vector] declares the column and the value has its shape), then binary, then any object or array, then
/// a string that parses to a JSON object or array, else a scalar. A string is never turned into a number.
///
/// [isAbsent] says the row carries no such field (`!row.containsKey(field)`), which Studio shows apart from a JSON
/// null; a field that holds a value cannot be absent, so that throws an [ArgumentError].
CellValue classifyCell(Object? value, {VectorColumn? vector, bool isAbsent = false}) {
  if (isAbsent) {
    if (value != null) throw ArgumentError.value(value, 'value', 'is a value of a field said to be absent');
    return const NullCell(isAbsent: true);
  }
  if (value == null) return const NullCell();
  if (vector != null) {
    final shape = _readVectorCell(value, vector);
    if (shape != null) return VectorCell._(shape, vector);
  }
  final bytes = _asBytes(value);
  if (bytes != null) return BinaryCell._(bytes);
  if (value is Map || value is List) return JsonCell._(value);
  if (value is String) return _parsesToJsonContainer(value) ? JsonCell._(value) : ScalarCell(value);
  if (value is num) return ScalarCell(jsNumberText(value));
  if (value is bool) return ScalarCell('$value');
  throw ArgumentError.value(value, 'value', 'is not a JSON value');
}

/// [row] as the result grid's Copy Row as JSON writes it (`copyRow`, `src/components/ResultsGrid.tsx:491-514`):
/// `jsonText(binaryCellsAsHex(row), 2)`. Each field in the row's own order, a binary field as its `\x` hex string, a
/// binary value nested in a document as the document spells it, a number JavaScript cannot carry (NaN or an infinity)
/// as its word (`jsonSafe`, `src/lib/db/sql-writing/export-shared.ts`), and every other value as Studio sent it, so a
/// number stays a number and a number string a string. An integer past 2^53 keeps every digit, where Studio's reader
/// would round it. A masked row holds its masks, so they are written as the strings they are.
String rowJsonText(Map<String, Object?> row) => _JsJson.stringify({
  for (final MapEntry(:key, :value) in row.entries)
    key: switch (value == null ? null : _asBytes(value)) {
      final Uint8List bytes => BinaryCell._(bytes).detailText,
      null => _jsonSafe(value),
    },
}, indent: '  ');

/// [value] with every number JSON cannot carry written as its word, as Studio's `jsonSafe` does.
Object? _jsonSafe(Object? value) => switch (value) {
  final double number when number.isNaN => 'NaN',
  final double number when number.isInfinite => number > 0 ? 'Infinity' : '-Infinity',
  final List<dynamic> list => [for (final item in list) _jsonSafe(item)],
  final Map<dynamic, dynamic> map => {for (final MapEntry(:key, :value) in map.entries) key: _jsonSafe(value)},
  _ => value,
};

/// [value] as JavaScript's `String` prints a number, with no rounding: an `int` prints every digit (Dart's reader keeps
/// all 64 bits, where JavaScript would round past 2^53), and a `double` prints Dart's shortest form, which is
/// JavaScript's, except that a whole number drops the `.0` Dart adds and -0 prints as `0`.
String jsNumberText(num value) {
  if (value is int) return value.toString();
  if (value == 0) return '0';
  final text = value.toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

// Only containers count: a string holding a bare JSON primitive ("true", "123") stays scalar, and the first-character
// test skips the parse for the common string cell.
bool _parsesToJsonContainer(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return false;
  try {
    final parsed = jsonDecode(trimmed);
    return parsed is Map || parsed is List;
  } on FormatException {
    return false;
  }
}

/// [value] as its bytes, or null when it is not `{type: "Buffer", data: [...]}` with every element a byte
/// (`asBytes`, `src/lib/db/sql-writing/export-shared.ts`), so a document with a `type` field stays a document.
Uint8List? _asBytes(Object value) {
  if (value is! Map || value['type'] != 'Buffer') return null;
  final data = value['data'];
  if (data is! List) return null;
  final bytes = Uint8List(data.length);
  for (var index = 0; index < data.length; index++) {
    final element = data[index];
    if (!_isInteger(element) || (element as num) < 0 || element > 255) return null;
    bytes[index] = element.toInt();
  }
  return bytes;
}

/// JavaScript's `Number.isInteger`: a whole number, which Dart's reader may hand as a `double`.
bool _isInteger(Object? value) => value is int || (value is double && value.isFinite && value == value.truncate());

/// JSON's insignificant whitespace (space, tab, newline, carriage return) dropped outside string literals, so a stored
/// text can be compared with the compact encoding of its parse.
String _stripJsonWhitespace(String text) {
  final out = StringBuffer();
  var inString = false;
  var escaped = false;
  for (final unit in text.codeUnits) {
    if (inString) {
      out.writeCharCode(unit);
      if (escaped) {
        escaped = false;
      } else if (unit == 0x5c) {
        escaped = true;
      } else if (unit == 0x22) {
        inString = false;
      }
    } else if (unit == 0x22) {
      inString = true;
      out.writeCharCode(unit);
    } else if (unit != 0x20 && unit != 0x09 && unit != 0x0a && unit != 0x0d) {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// Whether [value] holds an integer past 2^53, which Dart's reader keeps exact but Studio's rounds, or a number past
/// the double range, which both read as an infinity and JavaScript writes as `null`; either makes a text lossy, so it
/// keeps its stored form, as it does in Studio.
bool _holdsLossyNumber(Object? value) => switch (value) {
  final int number => number.abs() > _maxSafeInteger,
  final double number => !number.isFinite,
  final Map<String, dynamic> map => map.values.any(_holdsLossyNumber),
  final List<dynamic> list => list.any(_holdsLossyNumber),
  _ => false,
};

const _maxSafeInteger = 9007199254740991;

/// JavaScript's `JSON.stringify` over a value Dart's JSON reader gave: numbers as [jsNumberText] prints them, strings
/// escaped as both write them.
abstract final class _JsJson {
  static String stringify(Object? value, {String indent = ''}) {
    final out = StringBuffer();
    _write(out, value, indent, '');
    return out.toString();
  }

  static void _write(StringBuffer out, Object? value, String indent, String current) {
    switch (value) {
      case null:
        out.write('null');
      case final bool flag:
        out.write(flag);
      case final num number:
        // JSON.stringify writes an infinity as null.
        out.write(number.isFinite ? jsNumberText(number) : 'null');
      case final String text:
        out.write(jsonEncode(text));
      case final List<dynamic> list:
        _writeItems(out, '[', ']', list.length, indent, current, (index, inner) {
          _write(out, list[index], indent, inner);
        });
      case final Map<dynamic, dynamic> map:
        final entries = map.entries.toList();
        _writeItems(out, '{', '}', entries.length, indent, current, (index, inner) {
          out
            ..write(jsonEncode('${entries[index].key}'))
            ..write(indent.isEmpty ? ':' : ': ');
          _write(out, entries[index].value, indent, inner);
        });
      default:
        throw ArgumentError.value(value, 'value', 'is not a JSON value');
    }
  }

  static void _writeItems(
    StringBuffer out,
    String open,
    String close,
    int count,
    String indent,
    String current,
    void Function(int index, String inner) writeItem,
  ) {
    if (count == 0) {
      out.write('$open$close');
      return;
    }
    final inner = '$current$indent';
    out.write(open);
    for (var index = 0; index < count; index++) {
      if (index > 0) out.write(',');
      if (indent.isNotEmpty) out.write('\n$inner');
      writeItem(index, inner);
    }
    if (indent.isNotEmpty) out.write('\n$current');
    out.write(close);
  }
}

/// The shape of a vector cell, read as `readVectorCell` in `renderers/vector.ts` reads it.
sealed class _VectorShape {
  const _VectorShape();
}

final class _Dense extends _VectorShape {
  const _Dense(this.values);
  final List<num?> values;
}

final class _Multi extends _VectorShape {
  const _Multi(this.rows);
  final List<List<num?>> rows;
}

/// A sparse cell, with its entries in index order for the preview, as `sparseFromCell` sorts them.
sealed class _Sparse extends _VectorShape {
  const _Sparse(this.sortedIndices, this.sortedValues);
  final List<num> sortedIndices;
  final List<num> sortedValues;
}

final class _IndexMap extends _Sparse {
  const _IndexMap(this.entries, super.sortedIndices, super.sortedValues);

  /// The entries in the order the answer gave them, which JavaScript already put in its own key order.
  final List<(String, num)> entries;
}

final class _IndicesValues extends _Sparse {
  const _IndicesValues(this.indices, this.values, super.sortedIndices, super.sortedValues);
  final List<num> indices;
  final List<num> values;
}

/// A finite number, or null where the engine stored one it could not represent.
bool _isElement(Object? value) => value == null || (value is num && value.isFinite);

List<num?>? _elementRow(Object? value) =>
    value is List && value.every(_isElement) ? List<num?>.unmodifiable(value) : null;

_VectorShape? _readVectorCell(Object value, VectorColumn column) {
  switch (column.kind) {
    case 'dense':
      final values = _elementRow(value);
      return values == null ? null : _Dense(values);
    case 'multi':
      if (value is! List) return null;
      final rows = <List<num?>>[];
      for (final row in value) {
        final elements = _elementRow(row);
        if (elements == null) return null;
        rows.add(elements);
      }
      return _Multi(rows);
    case 'sparse':
      return _readSparse(value, column.sparseEncoding);
    default:
      // A kind this build does not know describes no cell, so the cell draws as what it is.
      return null;
  }
}

final _canonicalIndex = RegExp(r'^(?:0|[1-9][0-9]*)$');

_Sparse? _readSparse(Object value, String? encoding) {
  if (value is! Map) return null;
  switch (encoding) {
    case 'index-map':
      final entries = <(String, num)>[];
      for (final MapEntry(:key, :value) in value.entries) {
        if (key is! String || !_canonicalIndex.hasMatch(key) || value is! num || !value.isFinite) return null;
        entries.add((key, value));
      }
      final sorted = _sorted(
        [for (final entry in entries) num.parse(entry.$1)],
        [for (final entry in entries) entry.$2],
      );
      return _IndexMap(entries, sorted.$1, sorted.$2);
    case 'indices-values':
      final indices = value['indices'];
      final values = value['values'];
      if (indices is! List || values is! List || indices.length != values.length) return null;
      if (!indices.every(_isInteger) || !values.every((element) => element is num && element.isFinite)) return null;
      final indexNumbers = List<num>.unmodifiable(indices);
      final valueNumbers = List<num>.unmodifiable(values);
      final sorted = _sorted(indexNumbers, valueNumbers);
      return _IndicesValues(indexNumbers, valueNumbers, sorted.$1, sorted.$2);
    default:
      // An encoding this build does not know is not read as one it does: the copy would not be the engine's own form.
      return null;
  }
}

/// The pairs in ascending index order, equal indices kept in the order they came, as JavaScript's stable sort keeps
/// them.
(List<num>, List<num>) _sorted(List<num> indices, List<num> values) {
  final order = [for (var position = 0; position < indices.length; position++) position]
    ..sort((a, b) {
      final byIndex = indices[a].compareTo(indices[b]);
      return byIndex != 0 ? byIndex : a.compareTo(b);
    });
  return ([for (final position in order) indices[position]], [for (final position in order) values[position]]);
}
