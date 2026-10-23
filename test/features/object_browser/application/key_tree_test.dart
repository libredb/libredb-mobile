import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/object_browser/application/key_tree.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';

void main() {
  test('groups the recorded user:* walk of db1 into one folder holding every key', () {
    final keys = <String>{};
    final types = <String, String>{};
    for (final name in ['keyscan_first', 'keyscan_next', 'keyscan_last']) {
      final page = ObjectBrowserJson.keyScanPage(File('test/fixtures/studio/$name.json').readAsStringSync());
      keys.addAll(page.keys);
      types.addAll(page.types);
    }

    final top = keyTreeRows(keys.toList(), types, ':');
    expect(top, const [KeyTreeFolder(prefix: 'user:', label: 'user:', depth: 0, count: 1203, expanded: false)]);

    final open = keyTreeRows(keys.toList(), types, ':', expanded: {'user:', 'user:2:'});
    expect(open[1], const KeyTreeFolder(prefix: 'user:2:', label: '2:', depth: 1, count: 2, expanded: true));
    expect(open.sublist(2, 4), const [
      KeyTreeKey(key: 'user:2:profile', label: 'profile', depth: 2, type: 'string'),
      KeyTreeKey(key: 'user:2:roles', label: 'roles', depth: 2, type: 'set'),
    ]);
    expect(open.whereType<KeyTreeKey>().where((k) => k.depth == 1).first.label, '0001');
    expect(open.contains(const KeyTreeKey(key: 'user:2', label: '2', depth: 1, type: 'hash')), isTrue);
  });

  test('puts folders before keys, each sorted, and a key without a separator at the top', () {
    final rows = keyTreeRows(['b:1', 'a', 'a:x:1', 'c'], const {'a': 'string'}, ':');

    expect(rows, const [
      KeyTreeFolder(prefix: 'a:', label: 'a:', depth: 0, count: 1, expanded: false),
      KeyTreeFolder(prefix: 'b:', label: 'b:', depth: 0, count: 1, expanded: false),
      KeyTreeKey(key: 'a', label: 'a', depth: 0, type: 'string'),
      KeyTreeKey(key: 'c', label: 'c', depth: 0),
    ]);
  });

  test('groups by the declared separator, with a leading separator as an empty first segment', () {
    final rows = keyTreeRows(
      ['/apisix/routes/1', '/apisix/routes/2', '/apisix/upstreams/1'],
      const {},
      '/',
      expanded: {'/', '/apisix/'},
    );

    expect(rows.take(4), const [
      KeyTreeFolder(prefix: '/', label: '/', depth: 0, count: 3, expanded: true),
      KeyTreeFolder(prefix: '/apisix/', label: 'apisix/', depth: 1, count: 3, expanded: true),
      KeyTreeFolder(prefix: '/apisix/routes/', label: 'routes/', depth: 2, count: 2, expanded: false),
      KeyTreeFolder(prefix: '/apisix/upstreams/', label: 'upstreams/', depth: 2, count: 1, expanded: false),
    ]);
  });

  test('labels a key that ends in the separator by its full name', () {
    expect(
      keyTreeRows(['a:'], const {}, ':', expanded: {'a:'}).last,
      const KeyTreeKey(key: 'a:', label: 'a:', depth: 1),
    );
  });
}
