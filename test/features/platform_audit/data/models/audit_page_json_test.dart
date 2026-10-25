import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_audit/data/models/audit_page_json.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';

Map<String, Object?> _event({Map<String, Object?> override = const {}, Set<String> omit = const {}}) {
  final event = <String, Object?>{
    'eventId': '101',
    'startedAt': '2026-10-25T09:00:00.000Z',
    'finishedAt': '2026-10-25T09:00:00.250Z',
    'subject': 'kc-subject-alice',
    'username': 'alice.stone',
    'sessionRole': 'user',
    'connectionId': 'cm0connection000000000001',
    'connectionKnown': true,
    'connectionName': 'Payroll Archive',
    'engine': 'postgres',
    'accessLevel': 'read',
    'source': 'studio',
    'statementType': 'SELECT',
    'explain': 'analyze',
    'statementCapture': 'full',
    'statement': 'SELECT secret_column FROM payroll',
    'statementTruncated': false,
    'rowCount': 7,
    'durationMs': 250,
    'status': 'success',
    'errorCode': null,
    'errorMessage': null,
    'transactionOutcome': 'committed',
    ...override,
  };
  for (final field in omit) {
    event.remove(field);
  }
  return event;
}

String _body({List<Object?>? events, Object? total = 1, Set<String> omit = const {}}) => jsonEncode({
  if (!omit.contains('events')) 'events': events ?? [_event()],
  if (!omit.contains('total')) 'total': total,
});

AuditEvent _single(Map<String, Object?> event) => AuditPageJson.read(_body(events: [event]), offset: 0).events.single;

/// The values of [_event] a FormatException message must never carry.
const _values = ['kc-subject-alice', 'alice.stone', 'Payroll Archive', 'secret_column', 'cm0connection'];

void main() {
  test('reads every field of a page and its events', () {
    expect(
      AuditPageJson.read(_body(total: 120), offset: 50),
      AuditPage(
        events: [
          AuditEvent(
            eventId: '101',
            startedAt: DateTime.utc(2026, 10, 25, 9),
            finishedAt: DateTime.utc(2026, 10, 25, 9, 0, 0, 250),
            subject: 'kc-subject-alice',
            username: 'alice.stone',
            sessionRole: 'user',
            connectionId: 'cm0connection000000000001',
            connectionKnown: true,
            connectionName: 'Payroll Archive',
            engine: 'postgres',
            accessLevel: 'read',
            source: 'studio',
            statementType: 'SELECT',
            explain: 'analyze',
            statementCapture: 'full',
            statement: 'SELECT secret_column FROM payroll',
            statementTruncated: false,
            rowCount: 7,
            durationMs: 250,
            status: 'success',
            errorCode: null,
            errorMessage: null,
            transactionOutcome: 'committed',
          ),
        ],
        total: 120,
        offset: 50,
      ),
    );
  });

  test('reads startedAt and finishedAt as UTC times', () {
    final event = _single(_event(override: {'startedAt': '2026-10-25T12:00:00+03:00'}));

    expect(event.startedAt.isUtc, isTrue);
    expect(event.startedAt, DateTime.utc(2026, 10, 25, 9));
    expect(event.finishedAt!.isUtc, isTrue);
  });

  test('keeps the events in Platform order', () {
    final page = AuditPageJson.read(
      _body(
        events: [
          _event(override: {'eventId': '3'}),
          _event(override: {'eventId': '1'}),
          _event(override: {'eventId': '2'}),
        ],
        total: 3,
      ),
      offset: 0,
    );

    expect(page.events.map((event) => event.eventId), ['3', '1', '2']);
  });

  test('throws a FormatException for a missing events list or a missing integer total', () {
    expect(() => AuditPageJson.read(_body(omit: {'events'}), offset: 0), throwsFormatException);
    expect(() => AuditPageJson.read(_body(events: [], omit: {'total'}), offset: 0), throwsFormatException);
    expect(() => AuditPageJson.read(_body(total: '1'), offset: 0), throwsFormatException);
    expect(() => AuditPageJson.read(_body(total: 1.5), offset: 0), throwsFormatException);
    expect(() => AuditPageJson.read('{"events":{},"total":0}', offset: 0), throwsFormatException);
  });

  test('throws a FormatException when the body is not an object or an event is not one', () {
    expect(() => AuditPageJson.read('[]', offset: 0), throwsFormatException);
    expect(() => AuditPageJson.read(_body(events: ['101']), offset: 0), throwsFormatException);
  });

  // The required fields and a value of the wrong type for each.
  const required = <String, Object>{
    'eventId': 101,
    'startedAt': 1729846800,
    'subject': 1,
    'connectionId': 1,
    'connectionName': false,
    'source': 1,
    'statementType': 1,
    'status': 1,
    'statementCapture': 1,
    'statementTruncated': 'false',
    'durationMs': '250',
  };
  for (final MapEntry(key: field, value: wrong) in required.entries) {
    test('throws a FormatException naming $field when it is missing, and no value of the body', () {
      expect(
        () => _single(_event(omit: {field})),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains(field))
              .having((e) => _values.where(e.message.contains), 'values', isEmpty),
        ),
      );
    });

    test('throws a FormatException naming $field when it has the wrong type', () {
      expect(
        () => _single(_event(override: {field: wrong})),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(field))),
      );
    });
  }

  test('throws a FormatException for a startedAt that is not an ISO time, without the value', () {
    expect(
      () => _single(_event(override: {'startedAt': 'Payroll Archive'})),
      throwsA(
        isA<FormatException>()
            .having((e) => e.message, 'message', contains('startedAt'))
            .having((e) => e.message, 'message', isNot(contains('Payroll'))),
      ),
    );
  });

  test('throws a FormatException for a durationMs that is a fraction', () {
    expect(() => _single(_event(override: {'durationMs': 2.5})), throwsFormatException);
  });

  test('keeps an unknown status, statementType, source and statementCapture verbatim', () {
    final event = _single(
      _event(
        override: {
          'status': 'timed-out',
          'statementType': 'MERGE',
          'source': 'mobile-app',
          'statementCapture': 'hashed',
        },
      ),
    );

    expect(event.status, 'timed-out');
    expect(event.statementType, 'MERGE');
    expect(event.source, 'mobile-app');
    expect(event.statementCapture, 'hashed');
  });

  // The optional fields and a value of an unexpected type for each.
  const optional = <String, Object>{
    'finishedAt': 12,
    'username': 1,
    'sessionRole': 1,
    'connectionKnown': 'true',
    'engine': 1,
    'accessLevel': 1,
    'explain': true,
    'statement': 1,
    'rowCount': '7',
    'errorCode': 42501,
    'errorMessage': 1,
    'transactionOutcome': 1,
  };
  for (final MapEntry(key: field, value: wrong) in optional.entries) {
    test('reads $field as null when it is missing or of an unexpected type', () {
      expect(_value(_single(_event(omit: {field}))), isNot(contains(field)));
      expect(_value(_single(_event(override: {field: wrong}))), isNot(contains(field)));
    });
  }

  test('reads a finishedAt that is not an ISO time as null', () {
    expect(_single(_event(override: {'finishedAt': 'later'})).finishedAt, isNull);
  });

  test('reads a statementCapture of none with a null statement', () {
    final event = _single(_event(override: {'statementCapture': 'none', 'statement': null}));

    expect(event.statementCapture, 'none');
    expect(event.statement, isNull);
  });

  test('reads an unknown connection', () {
    final event = _single(
      _event(override: {'connectionKnown': false, 'connectionName': 'unknown connection', 'engine': null}),
    );

    expect(event.connectionKnown, isFalse);
    expect(event.connectionName, 'unknown connection');
    expect(event.engine, isNull);
  });
}

/// The names of the optional fields of [event] that are set.
Set<String> _value(AuditEvent event) => {
  if (event.finishedAt != null) 'finishedAt',
  if (event.username != null) 'username',
  if (event.sessionRole != null) 'sessionRole',
  if (event.connectionKnown != null) 'connectionKnown',
  if (event.engine != null) 'engine',
  if (event.accessLevel != null) 'accessLevel',
  if (event.explain != null) 'explain',
  if (event.statement != null) 'statement',
  if (event.rowCount != null) 'rowCount',
  if (event.errorCode != null) 'errorCode',
  if (event.errorMessage != null) 'errorMessage',
  if (event.transactionOutcome != null) 'transactionOutcome',
};
