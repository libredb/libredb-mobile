import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_connections/data/models/platform_connections_model.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

void main() {
  Map<String, Object?> item({
    Object? id = 'c1',
    Object? name = 'Orders',
    Object? engine = 'postgres',
    Object? status = 'active',
    Object? hasWriteCredential = true,
  }) => {'id': id, 'name': name, 'engine': engine, 'status': status, 'hasWriteCredential': hasWriteCredential};

  String body(List<Object?> items) => jsonEncode({'connections': items});

  test('reads the mock in server order', () {
    final connections = PlatformConnectionsModel.read(File('assets/mock/GET_v1_connections.json').readAsStringSync());

    expect(connections.map((c) => c.engine), ['redis', 'mongodb', 'mysql', 'postgres']);
    expect(connections.first.name, 'İstanbul Önbellek');
    expect(
      connections[2],
      const PlatformConnection(
        id: 'cm0conn0000000000000000002',
        name: 'Legacy Billing',
        engine: 'mysql',
        status: 'inactive',
        hasWriteCredential: false,
      ),
    );
  });

  test('keeps an unknown engine and an unknown status as Platform sent them', () {
    final connection = PlatformConnectionsModel.read(body([item(engine: 'cockroach', status: 'archived')])).single;

    expect(connection.engine, 'cockroach');
    expect(connection.status, 'archived');
    expect(connection.isActive, isFalse);
    expect(connection.isInactive, isFalse);
  });

  test('names an active and an inactive status', () {
    final connections = PlatformConnectionsModel.read(body([item(), item(id: 'c2', status: 'inactive')]));

    expect(connections.map((c) => (c.isActive, c.isInactive)), [(true, false), (false, true)]);
  });

  test('reads an empty install', () {
    expect(PlatformConnectionsModel.read(body([])), isEmpty);
  });

  group('throws a FormatException', () {
    final cases = <String, String>{
      'a body that is not an object': '[]',
      'a missing connections': '{}',
      'a connections that is not a list': '{"connections":{}}',
      'an item that is not an object': body(['c1']),
      'a missing id': body([item()..remove('id')]),
      'a missing name': body([item()..remove('name')]),
      'a missing engine': body([item()..remove('engine')]),
      'a missing status': body([item()..remove('status')]),
      'a missing hasWriteCredential': body([item()..remove('hasWriteCredential')]),
      'a null id': body([item(id: null)]),
      'a numeric name': body([item(name: 7)]),
      'a numeric engine': body([item(engine: 1)]),
      'a boolean status': body([item(status: true)]),
      'a hasWriteCredential that is not a bool': body([item(hasWriteCredential: 'true')]),
    };
    for (final MapEntry(key: name, value: json) in cases.entries) {
      test('for $name', () {
        expect(() => PlatformConnectionsModel.read(json), throwsFormatException);
      });
    }
  });

  test('never puts a connection name into its error text', () {
    expect(
      () => PlatformConnectionsModel.read(body([item(name: 'Payroll Secret', hasWriteCredential: 'yes')])),
      throwsA(isA<FormatException>().having((e) => e.toString(), 'text', isNot(contains('Payroll')))),
    );
  });

  test("PlatformConnection's text never carries its name", () {
    const connection = PlatformConnection(
      id: 'c1',
      name: 'Payroll Secret',
      engine: 'postgres',
      status: 'active',
      hasWriteCredential: true,
    );

    expect(connection.toString(), isNot(contains('Payroll')));
  });
}
