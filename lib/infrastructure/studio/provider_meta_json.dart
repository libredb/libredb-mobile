import 'dart:convert';

import 'package:libredb_mobile/shared/models/provider_meta.dart';

/// Reads the answer of `POST /api/db/provider-meta`: `{capabilities, labels}` (`src/lib/db/types.ts` in Studio for
/// the shape).
///
/// Throws a [FormatException] when a required field is missing or has the wrong type; optional fields of an unexpected
/// type are left out, so a newer Studio that adds fields reads as before.
final class ProviderMetaJson {
  const ProviderMetaJson._();

  static ProviderMeta read(String body) {
    final answer = _map(jsonDecode(body), 'answer');
    final capabilities = _map(answer['capabilities'], 'capabilities');
    final keyScan = capabilities['keyScan'];
    final masking = capabilities['maskingExemptColumns'];
    final rowActions = capabilities['rowActions'];
    return ProviderMeta(
      queryLanguage: _string(capabilities['queryLanguage'], 'queryLanguage'),
      schemaRefreshPattern: _string(capabilities['schemaRefreshPattern'], 'schemaRefreshPattern'),
      queryDialect: _optionalString(capabilities['queryDialect']),
      explainFormat: _optionalString(capabilities['explainFormat']),
      maskingExemptColumns: masking is Map<String, dynamic>
          ? MaskingExemptColumn(
              column: _string(masking['column'], 'column'),
              reason: _string(masking['reason'], 'reason'),
            )
          : null,
      containerLevels: [
        for (final level in _list(capabilities['containerLevels'] ?? const [], 'containerLevels'))
          ContainerLevel(
            id: _string(_map(level, 'container level')['id'], 'id'),
            label: _string((level as Map)['label'], 'label'),
            labelPlural: _string(level['labelPlural'], 'labelPlural'),
          ),
      ],
      objectKinds: [
        for (final kind in _list(capabilities['objectKinds'] ?? const [], 'objectKinds')) _objectKind(kind),
      ],
      supportsExplain: capabilities['supportsExplain'] == true,
      supportsTransactions: capabilities['supportsTransactions'] == true,
      supportsQueryCancel: capabilities['supportsQueryCancel'] == true,
      supportsResultPagination: capabilities['supportsResultPagination'] == true,
      // Studio accepts only `false` for these two; absent leaves the decision to the query language.
      supportsColumnProfiling: capabilities['supportsColumnProfiling'] == false ? false : null,
      supportsSqlFormat: capabilities['supportsSqlFormat'] == false ? false : null,
      catalogSessions: capabilities['catalogSessions'] == true,
      tablesAreDerivedGroupings: capabilities['tablesAreDerivedGroupings'] == true,
      identifierQuoting: _optionalString(capabilities['identifierQuoting']),
      containerPathShapes: _optionalString(capabilities['containerPathShapes']) ?? 'exact',
      rowActions: [
        if (rowActions is List)
          for (final action in rowActions) _rowAction(action),
      ],
      keyScan: keyScan is Map<String, dynamic> ? _keyScan(keyScan) : null,
      labels: _labels(answer['labels']),
    );
  }

  static ObjectKind _objectKind(Object? item) {
    final kind = _map(item, 'object kind');
    final childKinds = kind['childKinds'];
    final group = kind['group'];
    return ObjectKind(
      id: _string(kind['id'], 'id'),
      role: _string(kind['role'], 'role'),
      label: _string(kind['label'], 'label'),
      labelPlural: _string(kind['labelPlural'], 'labelPlural'),
      hasSource: kind['hasSource'] == true,
      sourceLanguage: _optionalString(kind['sourceLanguage']),
      acceptsSourceEdits: kind['acceptsSourceEdits'] == true,
      hasColumns: kind['hasColumns'] == true,
      childKinds: childKinds is List ? [for (final child in childKinds) _string(child, 'child kind')] : const [],
      attachedTo: _optionalString(kind['attachedTo']),
      acceptsRowWrites: kind['acceptsRowWrites'] == true,
      keyBrowserOnly: kind['enumeratedBy'] == 'key-browser',
      countIsListing: kind['countIsListing'] == true,
      machineNamesWithheld: kind['machineNames'] == 'withheld',
      group: group is Map<String, dynamic>
          ? ObjectKindGroup(id: _string(group['id'], 'group id'), label: _string(group['label'], 'group label'))
          : null,
    );
  }

  static KindRowAction _rowAction(Object? item) {
    final action = _map(item, 'row action');
    return KindRowAction(
      id: _string(action['id'], 'row action id'),
      label: _string(action['label'], 'row action label'),
      kinds: [for (final kind in _list(action['kinds'], 'row action kinds')) _string(kind, 'row action kind')],
      activates: action['activates'] == true,
    );
  }

  static KeyScanSpec _keyScan(Map<String, dynamic> keyScan) {
    final levels = keyScan['levels'];
    return KeyScanSpec(
      defaultCount: _int(keyScan['defaultCount'], 'defaultCount'),
      maxCount: _int(keyScan['maxCount'], 'maxCount'),
      separator: _optionalString(keyScan['separator']) ?? ':',
      cursor: _optionalString(keyScan['cursor']) ?? 'decimal',
      pattern: _optionalString(keyScan['pattern']) ?? 'glob',
      totalScope: _optionalString(keyScan['totalScope']) ?? 'database',
      levels: levels is Map<String, dynamic> ? KeyScanLevels(rootKind: _optionalString(levels['rootKind'])) : null,
    );
  }

  static ProviderLabels _labels(Object? value) {
    if (value is! Map<String, dynamic>) return const ProviderLabels();
    return ProviderLabels(
      entityName: _optionalString(value['entityName']),
      entityNamePlural: _optionalString(value['entityNamePlural']),
      rowName: _optionalString(value['rowName']),
      rowNamePlural: _optionalString(value['rowNamePlural']),
      selectAction: _optionalString(value['selectAction']),
      generateAction: _optionalString(value['generateAction']),
      searchPlaceholder: _optionalString(value['searchPlaceholder']),
    );
  }

  static Map<String, dynamic> _map(Object? value, String what) =>
      value is Map<String, dynamic> ? value : throw FormatException('The $what is not an object');

  static List<dynamic> _list(Object? value, String what) =>
      value is List ? value : throw FormatException('The $what is not a list');

  static String _string(Object? value, String what) =>
      value is String ? value : throw FormatException('The $what is not a string');

  static String? _optionalString(Object? value) => value is String ? value : null;

  static int _int(Object? value, String what) =>
      value is int ? value : throw FormatException('The $what is not a whole number');
}
