import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';

/// Ports libredb-studio's renderer cases (c9989a6b5): `tests/unit/components/results-grid-renderers.test.ts`,
/// `tests/unit/components/results-grid-vector-renderer.test.ts` and the copy rules of
/// `tests/components/results-grid/RowDetailSheet.test.tsx`, and reads the recorded and hand-written query answers.
void main() {
  VectorColumn column(String kind, String dtype, [int? dimension, String? sparseEncoding]) =>
      VectorColumn(kind: kind, dtype: dtype, dimension: dimension, sparseEncoding: sparseEncoding);

  Map<String, Object?> buffer(List<Object?> data) => {'type': 'Buffer', 'data': data};

  group('classifyCell', () {
    test('null is a NULL cell', () {
      expect(classifyCell(null), isA<NullCell>());
    });

    test('strings, numbers and booleans are scalar', () {
      for (final value in ['hello', '', 42, 0, 1.5, true, false]) {
        expect(classifyCell(value), isA<ScalarCell>(), reason: '$value');
      }
    });

    test('objects and arrays are JSON', () {
      for (final value in [
        {'a': 1},
        <String, Object?>{},
        [1, 2, 3],
        <Object?>[],
      ]) {
        expect(classifyCell(value), isA<JsonCell>(), reason: '$value');
      }
    });

    test('a string that parses to a JSON object or array is JSON', () {
      for (final value in ['{"a": 1}', '[1, 2]', '{\n  "id": "1",\n  "name": "Ada"\n}', '  {"padded": true}  ']) {
        expect(classifyCell(value), isA<JsonCell>(), reason: value);
      }
    });

    test('a string that parses to a JSON primitive stays scalar', () {
      for (final value in ['true', '123', '"quoted"', 'null']) {
        expect(classifyCell(value), isA<ScalarCell>(), reason: value);
      }
    });

    test('the string NULL is text, not the NULL marker', () {
      final cell = classifyCell('NULL');
      expect(cell, isA<ScalarCell>());
      expect(cell.compactText, 'NULL');
      expect(cell.detailText, 'NULL');
    });

    test('a non-JSON string stays scalar', () {
      for (final value in ['{not json', '[1, 2', 'plain text with { braces }']) {
        expect(classifyCell(value), isA<ScalarCell>(), reason: value);
      }
    });

    test('a byte-shaped value is binary', () {
      expect(classifyCell(buffer([1, 2, 171])), isA<BinaryCell>());
      expect(classifyCell(buffer([])), isA<BinaryCell>());
    });

    test('an object that only looks like a serialized Buffer stays JSON', () {
      expect(classifyCell({'type': 'Buffer'}), isA<JsonCell>());
      expect(classifyCell(buffer([1, 'two'])), isA<JsonCell>());
      expect(classifyCell(buffer([999])), isA<JsonCell>());
      expect(classifyCell(buffer([1.5])), isA<JsonCell>());
      expect(classifyCell(buffer([-1])), isA<JsonCell>());
    });

    test('a vector-shaped value without its column declaration stays JSON', () {
      expect(classifyCell([0.1, 0.2]), isA<JsonCell>());
      expect(
        classifyCell([
          [1, 2],
          [3, 4],
        ]),
        isA<JsonCell>(),
      );
      expect(
        classifyCell({
          'indices': [1],
          'values': [0.5],
        }),
        isA<JsonCell>(),
      );
      expect(classifyCell({'3': 0.5}), isA<JsonCell>());
    });

    test('a declared vector column classifies a value of its shape as a vector', () {
      expect(classifyCell([0.1, 0.2], vector: column('dense', 'float32', 2)), isA<VectorCell>());
      expect(
        classifyCell([
          [1, 2],
        ], vector: column('multi', 'float32', 2)),
        isA<VectorCell>(),
      );
      expect(
        classifyCell({
          'indices': [1],
          'values': [0.5],
        }, vector: column('sparse', 'float32', null, 'indices-values')),
        isA<VectorCell>(),
      );
    });

    test('a declared column whose value is not of its shape takes the next rule', () {
      final dense = column('dense', 'float32', 2);
      expect(classifyCell('***', vector: dense), isA<ScalarCell>());
      expect(classifyCell('[0.1,0.2]', vector: dense), isA<JsonCell>());
      expect(classifyCell({'a': 1}, vector: dense), isA<JsonCell>());
      expect(classifyCell([double.infinity], vector: dense), isA<JsonCell>());
      expect(classifyCell(buffer([1, 2]), vector: dense), isA<BinaryCell>());
      expect(classifyCell(null, vector: dense), isA<NullCell>());
    });
  });

  group('NULL', () {
    test('compact NULL, detail and copy null', () {
      final cell = classifyCell(null);
      expect(cell.compactText, 'NULL');
      expect(cell.detailText, 'null');
      expect(cell.copyText, 'null');
    });

    test('a field the row lacks is NULL in the cell, the detail and the copy, as Studio shows undefined', () {
      final cell = classifyCell(null, isAbsent: true);
      expect(cell, isA<NullCell>());
      expect(cell.compactText, 'NULL');
      expect(cell.detailText, 'NULL');
      expect(cell.copyText, 'NULL');
    });

    test('a field cannot be both absent and hold a value', () {
      expect(() => classifyCell('x', isAbsent: true), throwsArgumentError);
    });
  });

  group('scalar', () {
    test('a string is shown exactly as Studio sent it, digits included', () {
      final cell = classifyCell('9007199254740993');
      expect(cell.compactText, '9007199254740993');
      expect(cell.detailText, '9007199254740993');
      expect(cell.copyText, '9007199254740993');
      expect(classifyCell('12345678901234.123456').detailText, '12345678901234.123456');
      expect(classifyCell('a\nb').detailText, 'a\nb');
    });

    test('numbers print as JavaScript prints them, with no rounding', () {
      expect(classifyCell(42).compactText, '42');
      expect(classifyCell(1.5).compactText, '1.5');
      expect(classifyCell(3.141592653589793).compactText, '3.141592653589793');
      // Dart's reader gives an int for a literal within 64 bits, which keeps every digit.
      expect(classifyCell(jsonDecode('9007199254740993')).compactText, '9007199254740993');
      // A literal past 64 bits reads as a double; JavaScript prints it without a fraction.
      expect(classifyCell(jsonDecode('100000000000000000000')).compactText, '100000000000000000000');
      expect(classifyCell(1e21).compactText, '1e+21');
      expect(classifyCell(1.5e-7).compactText, '1.5e-7');
      expect(classifyCell(-0.0).compactText, '0');
      expect(classifyCell(2.0).compactText, '2');
    });

    test('booleans print as words, and detail and copy match the compact text', () {
      for (final value in [42, true, false, 'active', 'plain text']) {
        final cell = classifyCell(value);
        expect(cell.detailText, cell.compactText);
        expect(cell.copyText, cell.compactText);
      }
      expect(classifyCell(true).compactText, 'true');
    });
  });

  group('JSON', () {
    test('an object or array is compact JSON in the cell', () {
      expect(classifyCell({'a': 1}).compactText, '{"a":1}');
      expect(classifyCell([1, 2]).compactText, '[1,2]');
      expect(
        classifyCell({'n': 2.0, 'big': jsonDecode('9007199254740993')}).compactText,
        '{"n":2,"big":9007199254740993}',
      );
    });

    test('a JSON string keeps its raw text in the cell', () {
      const pretty = '{\n  "id": 1\n}';
      expect(classifyCell(pretty).compactText, pretty);
    });

    test('an object or array is pretty-printed with two spaces in the detail, and copied as the detail', () {
      final cell = classifyCell({
        'a': 1,
        'b': [1, 2],
      });
      expect(cell.detailText, '{\n  "a": 1,\n  "b": [\n    1,\n    2\n  ]\n}');
      expect(cell.copyText, cell.detailText);
      expect(classifyCell([1, 2]).detailText, '[\n  1,\n  2\n]');
      expect(classifyCell(<String, Object?>{}).detailText, '{}');
      expect(classifyCell({'e': <Object?>[]}).detailText, '{\n  "e": []\n}');
    });

    test('a JSON string is parsed and pretty-printed when the round trip is lossless', () {
      expect(classifyCell('{"id":1}').detailText, '{\n  "id": 1\n}');
      expect(classifyCell('{\n    "id": 1\n}').detailText, '{\n  "id": 1\n}');
      expect(classifyCell('{"id":"1","name":"Ada"}').copyText, '{\n  "id": "1",\n  "name": "Ada"\n}');
    });

    test('a JSON string keeps its stored text when the round trip would change a number', () {
      const bigInt = '{"n":9007199254740993}';
      expect(classifyCell(bigInt).detailText, bigInt);
      const trailingZero = '{"price":1.50}';
      expect(classifyCell(trailingZero).detailText, trailingZero);
      expect(classifyCell(trailingZero).copyText, trailingZero);
      const prettyLossy = '{\n  "n": 9007199254740993\n}';
      expect(classifyCell(prettyLossy).detailText, prettyLossy);
      const past64Bits = '[100000000000000000000]';
      expect(classifyCell(past64Bits).detailText, past64Bits);
    });

    test('whitespace inside JSON string values never makes the stored text win', () {
      expect(classifyCell('{"note":"a  b"}').detailText, '{\n  "note": "a  b"\n}');
      expect(classifyCell(r'{"quote":"she said \"hi\""}').detailText, '{\n  "quote": "she said \\"hi\\""\n}');
    });

    test('a JSON string with padding that JSON does not allow keeps its stored text', () {
      const padded = ' {"a":1}';
      final cell = classifyCell(padded);
      expect(cell, isA<JsonCell>());
      expect(cell.detailText, padded);
    });

    test('a JSON string holding a number past the double range keeps its stored text', () {
      for (final stored in ['[1e400]', '{"a":1e400}', '[-1e400]']) {
        final cell = classifyCell(stored);
        expect(cell, isA<JsonCell>(), reason: stored);
        expect(cell.detailText, stored);
        expect(cell.copyText, stored);
      }
    });

    test('an infinity inside an object or array is written as null, as JSON.stringify writes it', () {
      final cell = classifyCell({
        'a': [double.infinity, double.negativeInfinity],
      });
      expect(cell.compactText, '{"a":[null,null]}');
      expect(cell.detailText, '{\n  "a": [\n    null,\n    null\n  ]\n}');
    });

    test('a graph value has no kind of its own and renders as JSON', () {
      final cell = classifyCell({
        '~graph': {'nodes': <Object?>[]},
      });
      expect(cell, isA<JsonCell>());
      expect(cell.compactText, '{"~graph":{"nodes":[]}}');
    });
  });

  group('binary', () {
    test('hex in the cell, whole when short', () {
      final cell = classifyCell(buffer([1, 2, 171, 255])) as BinaryCell;
      expect(cell.compactText, r'\x0102abff');
      expect(cell.preview, r'\x0102abff');
      expect(cell.bytes, Uint8List.fromList([1, 2, 171, 255]));
      expect(cell.size, '4 B');
    });

    test('a 33-byte value previews 32 bytes and its size', () {
      final cell = classifyCell(buffer(List.filled(33, 0xab)));
      expect(cell.compactText, '\\x${'ab' * 32}... (33 B)');
      expect(classifyCell(buffer(List.filled(32, 0xab))).compactText, '\\x${'ab' * 32}');
    });

    test('a long value previews with its size in KB or MB', () {
      expect(classifyCell(buffer(List.filled(1024, 0xab))).compactText, '\\x${'ab' * 32}... (1.0 KB)');
      expect(classifyCell(buffer(List.filled(1024 * 1024, 0xab))).compactText, '\\x${'ab' * 32}... (1.0 MB)');
    });

    test('the detail and the copy are the whole value', () {
      final long = classifyCell(buffer(List.filled(1024, 0xab)));
      expect(long.detailText, '\\x${'ab' * 1024}');
      expect(long.copyText, '\\x${'ab' * 1024}');
      expect(classifyCell(buffer([])).detailText, r'\x');
      expect(classifyCell(buffer([])).copyText, r'\x');
    });
  });

  group('vector', () {
    final embedding = [for (var index = 0; index < 768; index++) ((index % 9) - 4) / 4];
    final embeddingCopy =
        '[${embedding.map((value) => value == value.roundToDouble() ? value.toStringAsFixed(1) : '$value').join(',')}]';

    String compact(Object? value, VectorColumn vector) => classifyCell(value, vector: vector).compactText;
    String copy(Object? value, VectorColumn vector) => classifyCell(value, vector: vector).copyText;

    test('a dense cell shows its first 8 elements, an ellipsis and its dimension', () {
      expect(
        compact(embedding, column('dense', 'float32', 768)),
        '[-1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, …] 768 dims',
      );
    });

    test('a 1536-element dense vector shows 8 elements and the count, and never builds its copy for the cell', () {
      final value = [for (var index = 0; index < 1536; index++) index / 2];
      final cell = classifyCell(value, vector: column('dense', 'float32', 1536)) as VectorCell;
      expect(cell.compactText, '[0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, …] 1536 dims');
      expect(cell.preview, '[0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, …]');
      expect(cell.size, '1536 dims');
      expect(cell.isCopyBuilt, isFalse);
      expect(cell.copy, startsWith('[0.0,0.5,1.0,'));
      expect(cell.isCopyBuilt, isTrue);
    });

    test('a short cell shows every element and no ellipsis, and its own length', () {
      expect(compact([1, 2.5], column('dense', 'float32')), '[1.0, 2.5] 2 dims');
      expect(compact([7], column('dense', 'float16')), '[7.0] 1 dim');
      expect(compact([-128, 0, 127], column('dense', 'int8', 3)), '[-128, 0, 127] 3 dims');
    });

    test('a binary vector shows its bytes and its bit count', () {
      expect(compact([0, 255], column('dense', 'binary', 16)), '[0, 255] 16 bits');
      expect(compact([85], column('dense', 'binary')), '[85] 8 bits');
      expect(
        compact([1, 2, 3, 4, 5, 6, 7, 8, 9], column('dense', 'binary', 72)),
        '[1, 2, 3, 4, 5, 6, 7, 8, …] 72 bits',
      );
    });

    test('a sparse cell shows its entries and their count, in either encoding', () {
      expect(
        compact({'3': 0.5, '10': 1}, column('sparse', 'float32', null, 'index-map')),
        '{3: 0.5, 10: 1.0} 2 entries',
      );
      expect(
        compact({
          'indices': [7],
          'values': [2],
        }, column('sparse', 'uint8', null, 'indices-values')),
        '{7: 2} 1 entry',
      );
      final ten = {
        'indices': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
        'values': [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      };
      expect(
        compact(ten, column('sparse', 'float32', null, 'indices-values')),
        '{0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0, 6: 1.0, 7: 1.0, …} 10 entries',
      );
    });

    test('a sparse cell previews in index order and copies in the order it came', () {
      final pairs = {
        'indices': [10, 3],
        'values': [1, 0.5],
      };
      final vector = column('sparse', 'float32', null, 'indices-values');
      expect(compact(pairs, vector), '{3: 0.5, 10: 1.0} 2 entries');
      expect(copy(pairs, vector), '{"indices":[10,3],"values":[1.0,0.5]}');
    });

    test('a multivector cell shows its first row and its row count', () {
      expect(
        compact([
          [1, 2],
          [3, 4],
        ], column('multi', 'float32', 2)),
        '[[1.0, 2.0], …] 2 rows of 2 dims',
      );
      expect(
        compact([
          [0.5],
        ], column('multi', 'float32')),
        '[[0.5]] 1 row of 1 dim',
      );
      expect(compact(<Object?>[], column('multi', 'float32')), '[] 0 rows of 0 dims');
      expect(compact(<Object?>[], column('multi', 'float32', 4)), '[] 0 rows of 4 dims');
    });

    test('a cell whose length differs from the declared dimension states its own length', () {
      expect(compact(<Object?>[], column('dense', 'float32', 768)), '[] 0 dims');
      expect(compact([1, 2], column('dense', 'float32', 768)), '[1.0, 2.0] 2 dims');
      expect(compact([255], column('dense', 'binary', 16)), '[255] 8 bits');
      expect(compact([<Object?>[]], column('multi', 'float32', 2)), '[[]] 1 row of 0 dims');
      expect(
        classifyCell([1, 2], vector: column('dense', 'float32', 768)).detailText,
        'dense float32, 2 dims\n[1.0,2.0]',
      );
    });

    test('the detail is a header line over the whole value', () {
      expect(
        classifyCell(embedding, vector: column('dense', 'float32', 768)).detailText,
        'dense float32, 768 dims\n$embeddingCopy',
      );
      expect(
        classifyCell({
          'indices': [3],
          'values': [0.5],
        }, vector: column('sparse', 'float32', null, 'indices-values')).detailText,
        'sparse float32, 1 entry\n{"indices":[3],"values":[0.5]}',
      );
    });

    test('a dense float cell copies every element, an integral one with a fraction', () {
      final text = copy(embedding, column('dense', 'float32', 768));
      expect(text, embeddingCopy);
      expect(jsonDecode(text), embedding);
    });

    test('a two-row integral multivector copies with a fraction on every element', () {
      expect(
        copy([
          [1, 2],
          [3, 4],
        ], column('multi', 'float32', 2)),
        '[[1.0,2.0],[3.0,4.0]]',
      );
      expect(
        copy([
          [1, 2],
        ], column('multi', 'uint8', 2)),
        '[[1.0,2.0]]',
      );
    });

    test('int8, uint8 and binary elements of a dense cell copy as integers', () {
      expect(copy([-128, 0, 127], column('dense', 'int8', 3)), '[-128,0,127]');
      expect(copy([0, 255], column('dense', 'uint8', 2)), '[0,255]');
      expect(copy([0, 255], column('dense', 'binary', 16)), '[0,255]');
    });

    test('float elements keep their exponent form, -0 keeps its sign and null stays null', () {
      final edge = [3.4028234663852886e38, 1e21, -0.0, 0, 1.401298464324817e-45, null];
      expect(
        copy(edge, column('dense', 'float32')),
        '[3.4028234663852886e+38,1e+21,-0.0,0.0,1.401298464324817e-45,null]',
      );
    });

    test('a sparse cell copies in its own encoding, indices as integers and values by element type', () {
      expect(copy({'3': 0.5, '10': 1}, column('sparse', 'float32', null, 'index-map')), '{"3":0.5,"10":1.0}');
      expect(
        copy({
          'indices': [3, 10],
          'values': [0.5, 1],
        }, column('sparse', 'float32', null, 'indices-values')),
        '{"indices":[3,10],"values":[0.5,1.0]}',
      );
      expect(
        copy({
          'indices': [3],
          'values': [2],
        }, column('sparse', 'uint8', null, 'indices-values')),
        '{"indices":[3],"values":[2]}',
      );
    });

    test('accepts a value of the shape its column declares', () {
      expect(classifyCell([0.1, null], vector: column('dense', 'float16', 2)), isA<VectorCell>());
      expect(
        classifyCell([
          [1],
          [2],
        ], vector: column('multi', 'float32', 1)),
        isA<VectorCell>(),
      );
      expect(classifyCell({'3': 0.5}, vector: column('sparse', 'float32', null, 'index-map')), isA<VectorCell>());
    });

    test('refuses a value its column does not describe', () {
      final dense = column('dense', 'float32', 2);
      for (final value in [
        '[1,2]',
        '***',
        {'a': 1},
        [1, '2'],
        [double.infinity],
        [double.nan],
        7,
      ]) {
        expect(classifyCell(value, vector: dense), isNot(isA<VectorCell>()), reason: '$value');
      }
      expect(classifyCell([1, 2], vector: column('multi', 'float32', 2)), isNot(isA<VectorCell>()));
      expect(
        classifyCell([
          [1],
          [double.infinity],
        ], vector: column('multi', 'float32', 1)),
        isNot(isA<VectorCell>()),
      );
      final pair = {
        'indices': [1],
        'values': [0.5],
      };
      expect(classifyCell(pair, vector: column('sparse', 'float32')), isNot(isA<VectorCell>()));
      expect(classifyCell(7, vector: column('sparse', 'float32', null, 'index-map')), isNot(isA<VectorCell>()));
      expect(
        classifyCell({'03': 0.5}, vector: column('sparse', 'float32', null, 'index-map')),
        isNot(isA<VectorCell>()),
      );
      expect(
        classifyCell({'3': null}, vector: column('sparse', 'float32', null, 'index-map')),
        isNot(isA<VectorCell>()),
      );
      expect(
        classifyCell({
          'indices': [1, 2],
          'values': [0.5],
        }, vector: column('sparse', 'float32', null, 'indices-values')),
        isNot(isA<VectorCell>()),
      );
      expect(
        classifyCell({
          'indices': [1.5],
          'values': [0.5],
        }, vector: column('sparse', 'float32', null, 'indices-values')),
        isNot(isA<VectorCell>()),
      );
    });

    test('refuses every value under a kind or sparse encoding it does not know', () {
      final unknown = column('Dense', 'float32', 3);
      for (final value in [
        [1, 2, 3],
        'abc',
        5,
      ]) {
        expect(classifyCell(value, vector: unknown), isNot(isA<VectorCell>()), reason: '$value');
      }
      final csr = column('sparse', 'float32', null, 'csr');
      expect(classifyCell(<String, Object?>{'1': 0.5}, vector: csr), isA<JsonCell>());
    });

    test('an element type it does not know is written as an integer, as Studio writes it', () {
      expect(copy([1, 2], column('dense', 'float8')), '[1,2]');
    });
  });

  group('recorded and hand-written answers', () {
    test('every column of query_types_postgres.json classifies as expected', () {
      final result = QueryResultJson.read(File('test/fixtures/studio/query_types_postgres.json').readAsStringSync());
      final row = result.rows.single;
      CellValue cell(String field) => classifyCell(row[field], vector: result.vectorColumns[field]);

      final bytea = cell('bytea_value');
      expect(bytea, isA<BinaryCell>());
      expect(bytea.compactText, r'\xdeadbeef');
      expect(bytea.copyText, r'\xdeadbeef');
      expect(cell('big_value'), isA<ScalarCell>());
      expect(cell('big_value').detailText, '9007199254740993');
      expect(cell('numeric_value'), isA<ScalarCell>());
      expect(cell('numeric_value').detailText, '12345678901234.123456');
      expect(cell('json_value'), isA<JsonCell>());
      expect(cell('json_value').compactText, '{"a":[1,2]}');
      expect(cell('jsonb_value'), isA<JsonCell>());
      expect(cell('int_array'), isA<JsonCell>());
      expect(cell('int_array').compactText, '[1,2,3]');
      expect(cell('text_array'), isA<JsonCell>());
      expect(cell('null_value'), isA<NullCell>());
      expect(cell('real_value').compactText, '1.5');
      expect(cell('double_value').compactText, '3.141592653589793');
      expect(cell('bool_value').compactText, 'true');
      for (final field in ['id', 'small_value', 'text_value', 'date_value', 'uuid_value', 'inet_value']) {
        expect(cell(field), isA<ScalarCell>(), reason: field);
      }
    });

    test('the nested documents of handwritten/mongodb/query_find.json classify as JSON', () {
      final result = QueryResultJson.read(
        File('test/fixtures/studio/handwritten/mongodb/query_find.json').readAsStringSync(),
      );
      final ada = result.rows[0];
      final grace = result.rows[1];

      expect(classifyCell(ada['_id']), isA<ScalarCell>());
      expect(classifyCell(ada['_id']).compactText, '6717a1f0c2a4e93b5f0d1e01');
      expect(classifyCell(ada['address']), isA<JsonCell>());
      expect(classifyCell(ada['address']).compactText, '{"city":"London","geo":{"lat":51.5072,"lng":-0.1276}}');
      expect(classifyCell(ada['tags']), isA<JsonCell>());
      expect(classifyCell(ada['created']), isA<ScalarCell>());
      // A field the document does not carry is absent, which Studio shows as NULL where a JSON null shows null.
      final absent = classifyCell(ada['payload'], isAbsent: !ada.containsKey('payload'));
      expect(absent, isA<NullCell>());
      expect(absent.detailText, 'NULL');
      expect(absent.copyText, 'NULL');

      final payload = classifyCell(grace['payload']);
      expect(payload, isA<JsonCell>());
      expect(payload.compactText, '{"type":"Buffer","data":[1,"two"]}');
      expect(classifyCell(grace['tags']).compactText, '[]');
      expect(classifyCell(grace['visits']).compactText, '0');
      expect(classifyCell(grace['address']), isA<NullCell>());
    });
  });
}
