import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/models/vector_column.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_functions.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:logger/logger.dart';

List<String> _recordWarnings() {
  final warnings = <String>[];
  void record(OutputEvent event) {
    if (event.level == Level.warning) warnings.addAll(event.lines);
  }

  Logger.addOutputListener(record);
  addTearDown(() => Logger.removeOutputListener(record));
  return warnings;
}

QueryResult _result(List<String> fields, List<Map<String, Object?>> rows) => QueryResult(
  fields: fields,
  rows: rows,
  rowCount: rows.length,
  executionTime: const Duration(milliseconds: 4),
  columnTypes: {for (final f in fields) f: 'text'},
  warnings: const [QueryWarning(message: 'notice')],
  pagination: const QueryPagination(limit: 100, offset: 0, hasMore: false, totalReturned: 1, wasLimited: false),
);

void main() {
  const clear = {
    'id': 7,
    'name': 'Alice',
    'email': 'alice@example.com',
    'password': 'hunter2-hunter2',
    'card_number': '4111111111111234',
    'phone': '+1-555-123-4567',
    'email (2)': 'alice.work@example.org',
    'address': 12,
  };
  final fields = clear.keys.toList();
  const exempt = MaskingExemptColumn(column: r'^address$', reason: 'A register number, not a place.');

  for (final role in const [StudioUserRole(), StudioAdminRole()]) {
    test('for ${role.name}, the sensitive columns are masked and the exempt column is not', () {
      final masked = maskResult(_result(fields, [clear]), MaskingPolicy.forRole(role, exempt: exempt));

      expect(masked.maskedColumns, {'email', 'password', 'card_number', 'phone', 'email (2)'});
      final row = masked.result.rows.single;
      expect(row, {
        'id': 7,
        'name': 'Alice',
        'email': 'a****@e**********',
        'password': '********',
        'card_number': '****-****-****-1234',
        'phone': '*******4567',
        'email (2)': 'a*********@e**********',
        'address': 12,
      });
    });
  }

  test('without the exemption the address column is masked too', () {
    final masked = maskResult(_result(fields, [clear]), MaskingPolicy.forRole(const StudioUserRole()));
    expect(masked.maskedColumns, contains('address'));
    expect(masked.result.rows.single['address'], '********');
  });

  test('a NULL in a masked column stays NULL, and an absent value stays absent', () {
    final masked = maskResult(
      _result(
        ['id', 'email'],
        [
          {'id': 1, 'email': null},
          {'id': 2},
        ],
      ),
      MaskingPolicy.forRole(null),
    );
    expect(masked.result.rows, [
      {'id': 1, 'email': null},
      {'id': 2},
    ]);
    expect(masked.maskedColumns, {'email'});
  });

  test('the corrected Token/Key, email and Birthdate rules apply to a result', () {
    final masked = maskResult(
      _result(
        ['token', 'email', 'email (2)', 'dob', 'birth_date'],
        [
          {
            'token': 'abcdefghi',
            'email': '@example.com',
            'email (2)': 'bob@',
            'dob': '1990-05-17T00:00:00.000Z',
            'birth_date': '1990-05-17',
          },
        ],
      ),
      MaskingPolicy.forRole(const StudioUserRole()),
    );
    expect(masked.result.rows.single, {
      'token': 'a*******i',
      'email': '***@***.***',
      'email (2)': '***@***.***',
      'dob': '****-**-**',
      'birth_date': '****-**-17',
    });
    expect(masked.result.rows.single.values.join(), isNot(contains('undefined')));
  });

  test('keeps everything but the rows, and the row count, as the result had them', () {
    final input = _result(fields, [clear]);
    final masked = maskResult(input, MaskingPolicy.forRole(const StudioUserRole()));
    expect(masked.result.fields, input.fields);
    expect(masked.result.rowCount, input.rowCount);
    expect(masked.result.executionTime, input.executionTime);
    expect(masked.result.columnTypes, input.columnTypes);
    expect(masked.result.warnings, input.warnings);
    expect(masked.result.pagination, input.pagination);
  });

  // maskResult rebuilds the result field by field, so a field it forgot would fall back to its default. Every field
  // here is set to a value other than its default, and every prop but the rows must come back unchanged; a field added
  // to QueryResult later belongs in this result too.
  test('keeps every field but the rows, each set to a value other than its default', () {
    const input = QueryResult(
      fields: ['email', 'emb'],
      rows: [
        {'email': 'alice@example.com', 'emb': '[1,2,3]'},
      ],
      rowCount: 1,
      executionTime: Duration(milliseconds: 9),
      columnTypes: {'email': 'text', 'emb': 'vector'},
      warnings: [QueryWarning(message: 'notice', code: '01000', severity: 'NOTICE')],
      pagination: QueryPagination(limit: 1, offset: 3, hasMore: true, totalReturned: 1, wasLimited: true),
      openTransactionRolledBack: true,
      vectorColumns: {'emb': VectorColumn(kind: 'dense', dtype: 'float32', dimension: 3)},
    );

    final masked = maskResult(input, MaskingPolicy.forRole(const StudioUserRole())).result;

    expect(masked.rows, isNot(input.rows), reason: 'the rows must be masked, or this compares a result to itself');
    List<Object?> withoutRows(QueryResult result) => [
      for (final prop in result.props)
        if (!identical(prop, result.rows)) prop,
    ];
    expect(withoutRows(input), hasLength(input.props.length - 1));
    expect(withoutRows(masked), hasLength(masked.props.length - 1));
    expect(withoutRows(masked), withoutRows(input));
  });

  test('a result with no sensitive column comes back as it was, with no masked column', () {
    final input = _result(
      ['id', 'name'],
      [
        {'id': 1, 'name': 'Alice'},
      ],
    );
    final masked = maskResult(input, MaskingPolicy.forRole(const StudioUserRole()));
    expect(masked.result, same(input));
    expect(masked.maskedColumns, isEmpty);
  });

  test('no clear value of a masked column is reachable from the masked result', () {
    final input = _result(fields, [clear]);
    final masked = maskResult(input, MaskingPolicy.forRole(const StudioAdminRole()));
    final reachable = [masked.toString(), masked.result.toString(), masked.props.toString(), '${masked.result.rows}'];
    for (final secret in ['alice@example.com', 'hunter2', '4111111111111234', '555-123', 'alice.work']) {
      for (final text in reachable) {
        expect(text, isNot(contains(secret)));
      }
    }
    // The input is not changed, so the caller that drops it drops the last clear copy.
    expect(input.rows.single['email'], 'alice@example.com');
  });

  test('masks a value as JavaScript String prints it, so the mask never sees a document text', () {
    final masked = maskResult(
      _result(
        ['card_number', 'phone', 'ip', 'salary'],
        [
          {
            'card_number': {'number': '4111111111111234'},
            'phone': [5, 5, 5, 1, 2, 3, 4],
            'ip': [192, 168, 1, 100],
            'salary': 85000.0,
          },
        ],
      ),
      MaskingPolicy.forRole(const StudioUserRole()),
    );
    expect(masked.result.rows.single, {
      'card_number': '****-****-****-****',
      'phone': '***1234',
      'ip': '***',
      'salary': '***,***.**',
    });
  });

  group('jsString', () {
    test('prints like JavaScript String', () {
      expect(jsString('text'), 'text');
      expect(jsString(true), 'true');
      expect(jsString(false), 'false');
      expect(jsString(null), 'null');
      expect(jsString(42), '42');
      expect(jsString(-3), '-3');
      expect(jsString(85000.0), '85000');
      expect(jsString(1.5), '1.5');
      expect(jsString(-0.0), '0');
      expect(jsString(1e21), '1e+21');
      expect(jsString(1e-7), '1e-7');
      expect(jsString(0.000001), '0.000001');
      expect(jsString(1e20), '100000000000000000000');
      expect(jsString(9007199254740993), '9007199254740992');
      expect(jsString({'a': 1}), '[object Object]');
      expect(jsString(<Object?>[]), '');
      expect(
        jsString([
          1,
          null,
          [2, 3],
          {'a': 1},
          'x',
          1.0,
        ]),
        '1,,2,3,[object Object],x,1',
      );
    });
  });

  test('an exemption Dart cannot compile exempts nothing and warns once, naming the pattern', () {
    final warnings = _recordWarnings();
    // A pattern no other test uses, since the warning is written once per distinct pattern in the run.
    const pattern = '(address[ uncompilable in maskResult test';
    const broken = MaskingExemptColumn(column: pattern, reason: 'r');
    final input = _result(
      ['address', 'email'],
      [
        {'address': '221B Baker Street', 'email': 'a@b.co'},
      ],
    );

    final first = maskResult(input, MaskingPolicy.forRole(const StudioAdminRole(), exempt: broken));
    final second = maskResult(input, MaskingPolicy.forRole(const StudioUserRole(), exempt: broken));

    expect(first.maskedColumns, {'address', 'email'});
    expect(second.maskedColumns, {'address', 'email'});
    expect(first.result.rows.single['address'], '********');
    expect(warnings.where((line) => line.contains(pattern)), hasLength(1));
    expect(warnings.join('\n'), isNot(contains('Baker')));
  });
}
