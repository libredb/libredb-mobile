import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/application/connection_sections.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

StudioConnection _c(
  String id,
  String name, {
  String? group,
  String? environment,
  String? host,
  String? database,
  String type = 'postgres',
}) => StudioConnection(
  id: id,
  name: name,
  type: type,
  group: group,
  environment: environment,
  host: host,
  database: database,
);

void main() {
  group('groupConnections', () {
    test('puts each row under its group and the rows without one under Other, last', () {
      final sections = groupConnections([
        _c('seed:1', 'Orders', group: 'Sales'),
        _c('seed:2', 'Scratch'),
        _c('seed:3', 'Ledger', group: 'Finance'),
        _c('seed:4', 'Leads', group: 'Sales'),
      ]);

      expect(sections.map((s) => s.group), ['Finance', 'Sales', null]);
      expect(sections[1].connections.map((c) => c.name), ['Leads', 'Orders']);
      expect(sections[2].connections.map((c) => c.id), ['seed:2']);
    });

    test('sorts sections and rows by name without regard to case or the Turkish i, then by id', () {
      final sections = groupConnections([
        _c('seed:b', 'ırmak', group: 'zeta'),
        _c('seed:a', 'Irmak', group: 'zeta'),
        _c('seed:c', 'alpha', group: 'zeta'),
        _c('seed:d', 'x', group: 'İzmir'),
        _c('seed:e', 'x', group: 'Ankara'),
      ]);

      expect(sections.map((s) => s.group), ['Ankara', 'İzmir', 'zeta']);
      expect(sections.last.connections.map((c) => c.id), ['seed:c', 'seed:a', 'seed:b']);
    });

    test('sorts a Turkish letter by its base letter, as Studio localeCompare does', () {
      final sections = groupConnections([
        _c('seed:1', 'Tokat', group: 'Zeta'),
        _c('seed:2', 'Şube', group: 'Zeta'),
        _c('seed:3', 'Sakarya', group: 'Zeta'),
        _c('seed:4', 'x', group: 'Üretim'),
        _c('seed:5', 'x', group: 'Urla'),
        _c('seed:6', 'x', group: 'Çanakkale'),
        _c('seed:7', 'x', group: 'Denizli'),
        _c('seed:8', 'x', group: 'Ordu'),
        _c('seed:9', 'x', group: 'Ödemiş'),
        _c('seed:10', 'x', group: 'Ğ'),
        _c('seed:11', 'x', group: 'Hatay'),
      ]);

      expect(sections.map((s) => s.group), [
        'Çanakkale',
        'Denizli',
        'Ğ',
        'Hatay',
        'Ödemiş',
        'Ordu',
        'Üretim',
        'Urla',
        'Zeta',
      ]);
      expect(sections.last.connections.map((c) => c.name), ['Sakarya', 'Şube', 'Tokat']);
    });

    test('puts a plain letter before the same Turkish letter when the names are otherwise equal', () {
      final sections = groupConnections([_c('seed:1', 'x', group: 'Şa'), _c('seed:2', 'x', group: 'Sa')]);

      expect(sections.map((s) => s.group), ['Sa', 'Şa']);
    });

    test('treats a blank group as no group', () {
      final sections = groupConnections([_c('seed:1', 'A', group: '  '), _c('seed:2', 'B', group: '')]);

      expect(sections.single.group, isNull);
      expect(sections.single.connections.map((c) => c.id), ['seed:1', 'seed:2']);
    });

    test('leaves out the Other section when every row has a group, and is empty for no rows', () {
      expect(groupConnections([_c('seed:1', 'A', group: 'G')]).map((s) => s.group), ['G']);
      expect(groupConnections(const []), isEmpty);
    });

    test('gives a group and Other keys that never collide', () {
      final sections = groupConnections([_c('seed:1', 'A', group: 'other'), _c('seed:2', 'B')]);

      expect(sections.map((s) => s.key).toSet(), hasLength(2));
    });
  });

  group('filterConnections', () {
    final rows = [
      _c('seed:1', 'Orders', group: 'Sales', environment: 'production', host: 'pg.sales.internal', database: 'sales'),
      _c('seed:2', 'Catalog', group: 'Ürünler', environment: 'staging', host: 'mongo.internal', database: 'catalog'),
      _c('seed:3', 'Kırılım', environment: 'development', database: '/data/kirilim.db', type: 'sqlite'),
    ];

    test('keeps every row for an empty query and no environment', () {
      expect(filterConnections(rows, query: '  '), rows);
    });

    test('matches the name, database, host and group, case-insensitively', () {
      expect(filterConnections(rows, query: 'ORDERS').map((c) => c.id), ['seed:1']);
      expect(filterConnections(rows, query: 'catalog').map((c) => c.id), ['seed:2']);
      expect(filterConnections(rows, query: 'pg.sales').map((c) => c.id), ['seed:1']);
      expect(filterConnections(rows, query: 'ürün').map((c) => c.id), ['seed:2']);
    });

    test('folds the Turkish dotted and dotless i', () {
      expect(filterConnections(rows, query: 'KIRILIM').map((c) => c.id), ['seed:3']);
      expect(filterConnections(rows, query: 'kirilim').map((c) => c.id), ['seed:3']);
    });

    test('does not match the engine type or the environment by text', () {
      expect(filterConnections(rows, query: 'sqlite'), isEmpty);
      expect(filterConnections(rows, query: 'production'), isEmpty);
    });

    test('keeps only the rows of the chosen environment, together with the query', () {
      expect(filterConnections(rows, query: '', environment: 'staging').map((c) => c.id), ['seed:2']);
      expect(filterConnections(rows, query: 'orders', environment: 'staging'), isEmpty);
    });
  });

  group('environmentsOf', () {
    test("lists the environments present in Studio's order, then any other string by name", () {
      final environments = environmentsOf([
        _c('seed:1', 'A', environment: 'other'),
        _c('seed:2', 'B', environment: 'local'),
        _c('seed:3', 'C', environment: 'qa'),
        _c('seed:4', 'D', environment: 'production'),
        _c('seed:5', 'E'),
        _c('seed:6', 'F', environment: 'production'),
      ]);

      expect(environments, ['production', 'local', 'other', 'qa']);
    });
  });
}
