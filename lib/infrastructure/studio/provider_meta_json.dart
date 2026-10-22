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
    final capabilities = _map(_map(jsonDecode(body), 'answer')['capabilities'], 'capabilities');
    final keyScan = capabilities['keyScan'];
    return ProviderMeta(
      queryLanguage: _string(capabilities['queryLanguage'], 'queryLanguage'),
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
      catalogSessions: capabilities['catalogSessions'] == true,
      keyScan: keyScan is Map<String, dynamic>
          ? KeyScanSpec(
              defaultCount: _int(keyScan['defaultCount'], 'defaultCount'),
              maxCount: _int(keyScan['maxCount'], 'maxCount'),
            )
          : null,
    );
  }

  static ObjectKind _objectKind(Object? item) {
    final kind = _map(item, 'object kind');
    return ObjectKind(
      id: _string(kind['id'], 'id'),
      role: _string(kind['role'], 'role'),
      label: _string(kind['label'], 'label'),
      labelPlural: _string(kind['labelPlural'], 'labelPlural'),
      hasSource: kind['hasSource'] == true,
      hasColumns: kind['hasColumns'] == true,
      attachedTo: kind['attachedTo'] is String ? kind['attachedTo'] as String : null,
      keyBrowserOnly: kind['enumeratedBy'] == 'key-browser',
    );
  }

  static Map<String, dynamic> _map(Object? value, String what) =>
      value is Map<String, dynamic> ? value : throw FormatException('The $what is not an object');

  static List<dynamic> _list(Object? value, String what) =>
      value is List ? value : throw FormatException('The $what is not a list');

  static String _string(Object? value, String what) =>
      value is String ? value : throw FormatException('The $what is not a string');

  static int _int(Object? value, String what) =>
      value is int ? value : throw FormatException('The $what is not a whole number');
}
