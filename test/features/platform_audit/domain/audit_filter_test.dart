import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';

void main() {
  test('trims every string value', () {
    final filter = AuditFilter(
      subject: '  kc-1 ',
      connectionId: ' cm0connection000000000001 ',
      source: ' studio ',
      statementType: ' SELECT ',
      status: ' error ',
      search: '  orders  ',
    );

    expect(filter.subject, 'kc-1');
    expect(filter.connectionId, 'cm0connection000000000001');
    expect(filter.source, 'studio');
    expect(filter.statementType, 'SELECT');
    expect(filter.status, 'error');
    expect(filter.search, 'orders');
  });

  test('unsets an empty or whitespace-only value', () {
    final filter = AuditFilter(
      subject: '',
      connectionId: '  ',
      source: '\t',
      statementType: '',
      status: ' ',
      search: '',
    );

    expect(filter, const AuditFilter());
    expect(filter.setFilterNames, isEmpty);
  });

  test('cuts search to its first 200 UTF-16 code units', () {
    final filter = AuditFilter(search: 'a' * 250);

    expect(filter.search, 'a' * 200);
  });

  test('keeps a surrogate pair at the cut whole by leaving it out', () {
    // The emoji takes code units 200 and 201, so a cut at 200 would split it.
    final filter = AuditFilter(search: '${'a' * 199}\u{1F600}b');

    expect(filter.search, 'a' * 199);
    expect(filter.search!.length, 199);
  });

  test('keeps a surrogate pair that ends right at the cut', () {
    final filter = AuditFilter(search: '${'a' * 198}\u{1F600}bc');

    expect(filter.search, '${'a' * 198}\u{1F600}');
  });

  test('names the set filters with Platform names, in a fixed order', () {
    final filter = AuditFilter(
      search: 'orders',
      to: DateTime.utc(2026, 10, 25),
      from: DateTime.utc(2026, 10, 1),
      status: 'error',
      statementType: 'SELECT',
      source: 'studio',
      connectionId: 'c1',
      subject: 'kc-1',
    );

    expect(filter.setFilterNames, [
      'subject',
      'connectionId',
      'source',
      'statementType',
      'status',
      'from',
      'to',
      'search',
    ]);
    expect(AuditFilter(status: 'success').setFilterNames, ['status']);
  });

  test('toString prints the set filter names and never a value', () {
    final filter = AuditFilter(
      subject: 'kc-alice',
      connectionId: 'conn-secret-id',
      source: 'studio',
      statementType: 'DELETE',
      status: 'refused',
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 25),
      search: 'select password from users',
    );

    final text = '$filter';

    expect(text, contains('subject'));
    expect(text, contains('search'));
    for (final value in ['kc-alice', 'conn-secret-id', 'DELETE', 'refused', '2026', 'password from users']) {
      expect(text, isNot(contains(value)));
    }
  });

  test('compares by value', () {
    expect(AuditFilter(status: 'error'), AuditFilter(status: ' error '));
    expect(AuditFilter(status: 'error'), isNot(AuditFilter(status: 'success')));
  });

  test('copyWith replaces the values it is given and keeps the others', () {
    final filter = AuditFilter(status: 'error', source: 'editor', from: DateTime.utc(2026, 10, 1));

    final changed = filter.copyWith(status: () => 'success', search: () => 'orders', from: () => null);

    expect(changed, AuditFilter(status: 'success', source: 'editor', search: 'orders'));
    expect(filter.copyWith(), filter);
  });

  test('copyWith unsets a value given as null', () {
    final filter = AuditFilter(subject: 'kc-1', connectionId: 'c1', to: DateTime.utc(2026, 10, 2));

    expect(filter.copyWith(subject: () => null, connectionId: () => null, to: () => null), const AuditFilter());
  });
}
