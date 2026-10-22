import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/tokens/engine_icons.dart';

void main() {
  test('gives the engines of one family the same icon', () {
    expect(engineIcon('postgres'), engineIcon('mysql'));
    expect(engineIcon('mongodb'), engineIcon('firestore'));
    expect(engineIcon('redis'), engineIcon('etcd'));
  });

  test('tells the families apart', () {
    final icons = {
      for (final type in ['postgres', 'sqlite', 'mongodb', 'redis', 'elasticsearch', 'neo4j', 'kafka', 's3'])
        engineIcon(type),
    };
    expect(icons, hasLength(8));
  });

  test('gives an unknown type the generic icon, since Studio may add engines', () {
    expect(engineIcon('cockroach-next'), genericEngineIcon);
    expect(engineIcon(''), genericEngineIcon);
    expect(genericEngineIcon, Icons.storage_outlined);
  });

  test('reads the type as an opaque string: another case is another type', () {
    expect(engineIcon('Postgres'), genericEngineIcon);
  });
}
