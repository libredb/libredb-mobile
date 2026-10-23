import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_fields.dart';

void main() {
  group('primaryField', () {
    test('takes the first field whose name holds a preferred word, in the order of the words', () {
      expect(primaryField(['id', 'email', 'full_name'], const []), 'full_name');
      expect(primaryField(['id', 'Description', 'Job_Title'], const []), 'Job_Title');
      expect(primaryField(['id', 'user_label', 'username'], const []), 'username');
      expect(primaryField(['id', 'note', 'contact_email'], const []), 'contact_email');
    });

    test('ignores case and takes the first of several fields with the same word', () {
      expect(primaryField(['ID', 'FIRST_NAME', 'last_name'], const []), 'FIRST_NAME');
    });

    test('a word inside another name counts, as Studio reads it', () {
      // `filename` holds `name`, so it wins over a later `title`.
      expect(primaryField(['filename', 'title'], const []), 'filename');
    });

    test('without a preferred name, takes the first field without id whose first value is a string', () {
      final rows = [
        {'id': 'a1', 'grid_id': 'b2', 'count': 3, 'city': 'Izmir', 'zone': 'east'},
      ];
      expect(primaryField(['id', 'grid_id', 'count', 'city', 'zone'], rows), 'city');
    });

    test('the string test reads only the first row', () {
      final rows = [
        {'code': null, 'city': 'Izmir'},
        {'code': 'x', 'city': 'Ankara'},
      ];
      expect(primaryField(['code', 'city'], rows), 'city');
    });

    test('a name with id anywhere in it is passed over, as in `valid`', () {
      final rows = [
        {'valid': 'yes', 'zone': 'east'},
      ];
      expect(primaryField(['valid', 'zone'], rows), 'zone');
    });

    test('falls back to the first field', () {
      expect(
        primaryField(
          ['id', 'count'],
          [
            {'id': 1, 'count': 2},
          ],
        ),
        'id',
      );
      expect(primaryField(['count', 'total'], const []), 'count');
    });

    test('a result without fields has none', () {
      expect(primaryField(const [], const []), isNull);
    });

    test('query_types_postgres.json: big_value, since a bigint arrives as a string', () {
      final result = QueryResultJson.read(File('test/fixtures/studio/query_types_postgres.json').readAsStringSync());
      expect(primaryField(result.fields, result.rows), 'big_value');
      expect(idField(result.fields), 'id');
    });
  });

  group('idField', () {
    test('takes the first field named id or ending in _id, ignoring case', () {
      expect(idField(['name', 'ID', 'user_id']), 'ID');
      expect(idField(['name', 'Order_ID', 'id']), 'Order_ID');
    });

    test('a name that only holds id is not one', () {
      expect(idField(['identity', 'idx', 'paid']), isNull);
    });
  });

  group('previewFields', () {
    test('takes up to four fields other than the title and the id field, in order', () {
      expect(previewFields(['id', 'name', 'a', 'b', 'c', 'd', 'e'], primary: 'name', id: 'id'), ['a', 'b', 'c', 'd']);
    });

    test('keeps every other field when there are fewer than four', () {
      expect(previewFields(['name', 'a', 'b'], primary: 'name', id: null), ['a', 'b']);
    });

    test('the title that is also the id field is left out once', () {
      expect(previewFields(['id', 'a'], primary: 'id', id: 'id'), ['a']);
    });
  });
}
