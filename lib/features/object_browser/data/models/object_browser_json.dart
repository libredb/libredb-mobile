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
  ///
  /// Every field Studio's type requires is read strictly, and a type, key or index name that is blank is refused,
  /// since a row without one says nothing; a column's name may be empty, as MongoDB names a field of an empty key.
  /// `indexes` is a list or Studio's filled `{unavailable}` sentence, and a column's `provenance` is a loss notice.
  /// `exclusionConstraints` is optional and left out when it is not a list, but each constraint in it needs its name
  /// and definition; a `declaredType` that is not a filled string is left out.
  static ObjectDetail detail(String body) {
    final json = _object(body);
    final indexes = json['indexes'];
    final exclusion = json['exclusionConstraints'];
    return ObjectDetail(
      path: _strings(json['path'], 'path'),
      columns: [for (final column in _list(json['columns'], 'columns')) _column(column)],
      foreignKeys: [for (final key in _list(json['foreignKeys'], 'foreignKeys')) _foreignKey(key)],
      indexes: indexes is Map ? null : [for (final index in _list(indexes, 'indexes')) _index(index)],
      indexesUnavailable: indexes is Map ? _filled(indexes['unavailable'], 'unavailable') : null,
      exclusionConstraints: [
        if (exclusion is List)
          for (final constraint in exclusion) _exclusionConstraint(constraint),
      ],
    );
  }

  static ForeignKeySchema _foreignKey(Object? item) {
    final key = _map(item, 'foreign key');
    return ForeignKeySchema(
      columnName: _filled(key['columnName'], 'columnName'),
      referencedTable: _filled(key['referencedTable'], 'referencedTable'),
      referencedColumn: _filled(key['referencedColumn'], 'referencedColumn'),
    );
  }

  static ExclusionConstraintSchema _exclusionConstraint(Object? item) {
    final constraint = _map(item, 'exclusion constraint');
    return ExclusionConstraintSchema(
      name: _filled(constraint['name'], 'name'),
      definition: _filled(constraint['definition'], 'definition'),
    );
  }

  static IndexSchema _index(Object? item) {
    final index = _map(item, 'index');
    return IndexSchema(
      name: _filled(index['name'], 'name'),
      columns: _strings(index['columns'], 'columns'),
      unique: _bool(index['unique'], 'unique'),
    );
  }

  /// `POST /api/db/objects/source`: `{path, kind, parts}`, one to eight parts with distinct ids, as Studio's client
  /// accepts it (`isSourceDocumentShape` in `src/components/object-source/source-reader.ts`).
  static ObjectSource source(String body) {
    final json = _object(body);
    final parts = _list(json['parts'], 'parts');
    if (parts.isEmpty) throw const FormatException('An object source has no parts');
    if (parts.length > _sourcePartLimit) throw const FormatException('An object source has more than eight parts');
    final read = [for (final part in parts) _sourcePart(part)];
    if (read.map((part) => part.id).toSet().length != read.length) {
      throw const FormatException('Two parts of an object source share an id');
    }
    return ObjectSource(path: _strings(json['path'], 'path'), kind: _string(json['kind'], 'kind'), parts: read);
  }

  /// Studio's `SOURCE_PART_LIMIT` (`src/lib/db/object-kinds.ts`).
  static const _sourcePartLimit = 8;

  /// `POST /api/db/keys/scan`: `KeyScanPage`.
  ///
  /// `skipped` and `readOutcome` report keys left out and reads that may be short, so either one, present but
  /// malformed or with a blank reason, fails the page rather than being dropped (decisions.md, #59).
  static KeyScanPage keyScanPage(String body) {
    final json = _object(body);
    final cursor = _string(json['cursor'], 'cursor');
    // Studio refuses an empty cursor on the next page, so an answer naming one is not a page the app can go on from.
    if (cursor.isEmpty) throw const FormatException('A key page has an empty cursor');
    final types = _map(json['types'], 'types');
    return KeyScanPage(
      keys: _strings(json['keys'], 'keys'),
      cursor: cursor,
      types: {
        for (final MapEntry(:key, :value) in types.entries)
          if (value is String) key: value,
      },
      total: _int(json['total'], 'total'),
      clustered: json['clustered'] is bool ? json['clustered'] as bool : null,
      skipped: json['skipped'] == null ? null : _skipped(json['skipped']),
      readOutcome: json['readOutcome'] == null ? null : _readOutcome(json['readOutcome']),
      prefixes: _optionalStrings(json['prefixes']),
    );
  }

  static KeyScanSkipped _skipped(Object? value) {
    final skipped = _map(value, 'skipped');
    return KeyScanSkipped(
      count: _int(skipped['count'], 'skipped count'),
      reason: _sentence(skipped['reason'], 'skipped reason'),
    );
  }

  static KeyReadOutcome _readOutcome(Object? value) {
    final outcome = _map(value, 'readOutcome');
    final provenLoss = outcome['provenLoss'];
    return KeyReadOutcome(
      scope: _sentence(outcome['scope'], 'readOutcome scope'),
      endReason: _sentence(outcome['endReason'], 'readOutcome endReason'),
      provenLoss: provenLoss == null ? const [] : List.unmodifiable(_strings(provenLoss, 'provenLoss')),
    );
  }

  /// A string that holds more than white space.
  static String _sentence(Object? value, String what) {
    final text = _string(value, what);
    return text.trim().isEmpty ? throw FormatException('The $what is blank') : text;
  }

  /// A list of strings, or null when [value] is anything else.
  static List<String>? _optionalStrings(Object? value) =>
      value is List && value.every((item) => item is String) ? List<String>.unmodifiable(value) : null;

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
    final declaredType = column['declaredType'];
    return ColumnSchema(
      name: _string(column['name'], 'name'),
      type: _filled(column['type'], 'type'),
      declaredType: declaredType is String && declaredType.trim().isNotEmpty ? declaredType : null,
      nullable: _bool(column['nullable'], 'nullable'),
      isPrimary: _bool(column['isPrimary'], 'isPrimary'),
      defaultValue: defaultValue is String ? defaultValue : null,
      sampled: _sampled(column),
    );
  }

  /// `provenance` is a loss notice: a sampled column says another row may carry a key the list lacks, so a value
  /// Studio does not send is refused rather than read as declared.
  static bool _sampled(Map<String, dynamic> column) {
    if (!column.containsKey('provenance')) return false;
    if (column['provenance'] == 'sampled') return true;
    throw const FormatException('The provenance of a column is not one Studio sends');
  }

  /// A text, a refusal (`unavailable`) or a neutral statement (`unavailable` with `statement: true`), refused as
  /// Studio's client refuses it (`isPartShape` in `src/components/object-source/source-reader.ts`): a part with both a
  /// text and a refusal, a `statement` that is not `true` or sits on a part without `unavailable`, an empty or blank
  /// string where Studio needs a filled one, a `form` or `origin` it does not send, and a `truncated` that is not a
  /// limit with a filled reason. `edit` is left out: the app does not edit source.
  static SourcePart _sourcePart(Object? item) {
    final part = _map(item, 'source part');
    final id = _filled(part['id'], 'id');
    final label = _filled(part['label'], 'label');
    final refused = part.containsKey('unavailable');
    if (refused && part.containsKey('text')) throw const FormatException('A source part has a text and a refusal');
    if (part.containsKey('statement') && (part['statement'] != true || !refused)) {
      throw const FormatException('A source part has a statement that is not a refusal marked true');
    }
    if (refused) {
      final reason = _filled(part['unavailable'], 'unavailable');
      return part['statement'] == true
          ? SourceStatement(id: id, label: label, statement: reason)
          : SourceUnavailable(id: id, label: label, reason: reason);
    }
    return SourceText(
      id: id,
      label: label,
      text: _filled(part['text'], 'text'),
      language: _filled(part['language'], 'language'),
      origin: _origin(part['origin']),
      complete: _complete(part['form']),
      truncated: part.containsKey('truncated') ? _truncation(part['truncated']) : null,
    );
  }

  static SourceTruncation _truncation(Object? value) {
    final truncated = _map(value, 'truncation');
    return SourceTruncation(limit: _int(truncated['limit'], 'limit'), reason: _filled(truncated['reason'], 'reason'));
  }

  static bool _complete(Object? form) => switch (form) {
    'complete' => true,
    'partial' => false,
    _ => throw const FormatException('The form of a source part is not one Studio sends'),
  };

  static SourceOrigin _origin(Object? value) {
    for (final origin in SourceOrigin.values) {
      if (origin.name == value) return origin;
    }
    throw const FormatException('The origin of a source part is not one Studio sends');
  }

  /// A string that holds more than white space, as Studio's `isFilledString` requires.
  static String _filled(Object? value, String what) {
    final string = _string(value, what);
    return string.trim().isEmpty ? throw FormatException('The $what is empty') : string;
  }

  static Map<String, dynamic> _object(String body) => _map(jsonDecode(body), 'answer');

  static Map<String, dynamic> _map(Object? value, String what) =>
      value is Map<String, dynamic> ? value : throw FormatException('The $what is not an object');

  static List<dynamic> _list(Object? value, String what) =>
      value is List ? value : throw FormatException('The $what is not a list');

  static String _string(Object? value, String what) =>
      value is String ? value : throw FormatException('The $what is not a string');

  static bool _bool(Object? value, String what) =>
      value is bool ? value : throw FormatException('The $what is not true or false');

  static int _int(Object? value, String what) =>
      value is int ? value : throw FormatException('The $what is not a whole number');

  static List<String> _strings(Object? value, String what) {
    final list = _list(value, what);
    return [for (final item in list) _string(item, what)];
  }
}
