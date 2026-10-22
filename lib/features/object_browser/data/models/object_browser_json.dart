import 'dart:convert';

import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';

/// Reads the answers of Studio's object routes (`src/lib/db/types.ts` in Studio for the shapes).
///
/// Every reader throws a [FormatException] when a required field is missing or has the wrong type; optional fields
/// of an unexpected type are left out, so a newer Studio that adds fields reads as before.
final class ObjectBrowserJson {
  const ObjectBrowserJson._();

  /// `POST /api/db/objects/containers`: `Container[]`.
  static List<ObjectContainer> containers(String body) => [
    for (final item in _list(jsonDecode(body), 'containers'))
      ObjectContainer(
        path: _strings(_map(item, 'container')['path'], 'path'),
        name: _string((item as Map)['name'], 'name'),
        level: _int(item['level'], 'level'),
        isSessionDefault: item['isSessionDefault'] == true,
        kinds: item['kinds'] is List ? _strings(item['kinds'], 'kinds') : null,
      ),
  ];

  /// `POST /api/db/objects/counts`: `{kindId: {count} | {count, sampledFrom} | {unavailable}}`.
  static Map<String, KindCount> counts(String body) => {
    for (final MapEntry(:key, :value) in _object(body).entries) key: _kindCount(value),
  };

  /// `POST /api/db/objects/list` and `POST /api/db/objects/search`: `DatabaseObject[]`.
  static List<DatabaseObject> objects(String body) => [
    for (final item in _list(jsonDecode(body), 'objects')) _databaseObject(item),
  ];

  /// `POST /api/db/objects/describe`: `ObjectDetail`.
  static ObjectDetail detail(String body) {
    final json = _object(body);
    final indexes = json['indexes'];
    return ObjectDetail(
      path: _strings(json['path'], 'path'),
      columns: [for (final column in _list(json['columns'], 'columns')) _column(column)],
      foreignKeys: [
        for (final key in _list(json['foreignKeys'] ?? const [], 'foreignKeys'))
          ForeignKeySchema(
            columnName: _string(_map(key, 'foreign key')['columnName'], 'columnName'),
            referencedTable: _string((key as Map)['referencedTable'], 'referencedTable'),
            referencedColumn: _string(key['referencedColumn'], 'referencedColumn'),
          ),
      ],
      indexes: indexes is List
          ? [
              for (final index in indexes)
                IndexSchema(
                  name: _string(_map(index, 'index')['name'], 'name'),
                  columns: _strings((index as Map)['columns'], 'columns'),
                  unique: index['unique'] == true,
                ),
            ]
          : null,
      indexesUnavailable: indexes is Map && indexes['unavailable'] is String ? indexes['unavailable'] as String : null,
    );
  }

  /// `POST /api/db/objects/source`: `{path, kind, parts}`.
  static ObjectSource source(String body) {
    final json = _object(body);
    final parts = _list(json['parts'], 'parts');
    if (parts.isEmpty) throw const FormatException('An object source has no parts');
    return ObjectSource(
      path: _strings(json['path'], 'path'),
      kind: _string(json['kind'], 'kind'),
      parts: [for (final part in parts) _sourcePart(part)],
    );
  }

  /// `POST /api/db/keys/scan`: `KeyScanPage`.
  static KeyScanPage keyScanPage(String body) {
    final json = _object(body);
    final types = json['types'];
    return KeyScanPage(
      keys: _strings(json['keys'], 'keys'),
      cursor: _string(json['cursor'], 'cursor'),
      types: {
        if (types is Map)
          for (final MapEntry(:key, :value) in types.entries)
            if (key is String && value is String) key: value,
      },
      total: _int(json['total'], 'total'),
    );
  }

  static KindCount _kindCount(Object? value) {
    final count = _map(value, 'kind count');
    if (count['unavailable'] is String) return KindCountUnavailable(count['unavailable'] as String);
    final sampledFrom = count['sampledFrom'];
    return KindCounted(_int(count['count'], 'count'), sampledFrom: sampledFrom is String ? sampledFrom : null);
  }

  static DatabaseObject _databaseObject(Object? item) {
    final object = _map(item, 'object');
    return DatabaseObject(
      path: _strings(object['path'], 'path'),
      name: _string(object['name'], 'name'),
      kind: _string(object['kind'], 'kind'),
      status: object['status'] is String ? object['status'] as String : null,
      rowCount: object['rowCount'] is int ? object['rowCount'] as int : null,
      sizeBytes: object['sizeBytes'] is int ? object['sizeBytes'] as int : null,
    );
  }

  static ColumnSchema _column(Object? item) {
    final column = _map(item, 'column');
    final defaultValue = column['defaultValue'] ?? column['defaultExpression'];
    return ColumnSchema(
      name: _string(column['name'], 'name'),
      type: _string(column['type'], 'type'),
      nullable: column['nullable'] == true,
      isPrimary: column['isPrimary'] == true,
      defaultValue: defaultValue is String ? defaultValue : null,
      sampled: column['provenance'] == 'sampled',
    );
  }

  static SourcePart _sourcePart(Object? item) {
    final part = _map(item, 'source part');
    final id = _string(part['id'], 'id');
    final label = _string(part['label'], 'label');
    if (part['unavailable'] is String) {
      return SourceUnavailable(id: id, label: label, reason: part['unavailable'] as String);
    }
    return SourceText(
      id: id,
      label: label,
      text: _string(part['text'], 'text'),
      language: _string(part['language'], 'language'),
      complete: part['form'] != 'partial',
      truncated: part['truncated'] != null,
    );
  }

  static Map<String, dynamic> _object(String body) => _map(jsonDecode(body), 'answer');

  static Map<String, dynamic> _map(Object? value, String what) =>
      value is Map<String, dynamic> ? value : throw FormatException('The $what is not an object');

  static List<dynamic> _list(Object? value, String what) =>
      value is List ? value : throw FormatException('The $what is not a list');

  static String _string(Object? value, String what) =>
      value is String ? value : throw FormatException('The $what is not a string');

  static int _int(Object? value, String what) =>
      value is int ? value : throw FormatException('The $what is not a whole number');

  static List<String> _strings(Object? value, String what) {
    final list = _list(value, what);
    return [for (final item in list) _string(item, what)];
  }
}
