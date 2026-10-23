import 'dart:convert';

import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_store.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';

/// Keeps the active connection of each signed-in user in the device preferences, under
/// [StorageKeys.activeConnection], as a JSON object from the SHA-256 of the subject to the connection id, so the
/// subject itself is never stored.
///
/// The value outlives the session, so the next sign-in of the same user opens the same connection, and a second account
/// on the device never reads the first one's.
class ActiveConnectionPreferences implements IActiveConnectionStore {
  ActiveConnectionPreferences({AppLocalStorage? storage}) : _storage = storage ?? AppLocalStorage();

  static final _log = AppLogger.getLogger('ActiveConnectionPreferences');

  final AppLocalStorage _storage;

  static final _key = StorageKeys.activeConnection.key;

  @override
  Future<String?> read(String subject) async => (await _readAll())[_hash(subject)];

  @override
  Future<void> write(String subject, String? connectionId) async {
    Map<String, String> all;
    try {
      all = await _readAll();
    } on FormatException catch (e) {
      _log.warn('{} cannot be read and is replaced: {}', [_key, e.message]);
      all = {};
    }
    if (connectionId == null) {
      all.remove(_hash(subject));
    } else {
      all[_hash(subject)] = connectionId;
    }
    final saved = await _storage.save(_key, jsonEncode(all));
    if (!saved) throw StateError('the device refused to store $_key');
  }

  Future<Map<String, String>> _readAll() async {
    final stored = await _storage.read(_key);
    if (stored == null) return {};
    if (stored is! String) throw FormatException('$_key is not a string: ${stored.runtimeType}');
    final Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      throw FormatException('$_key is not JSON');
    }
    if (decoded is! Map<String, Object?> || decoded.values.any((id) => id is! String)) {
      throw FormatException('$_key is not an object of connection ids');
    }
    return decoded.cast<String, String>();
  }

  static String _hash(String subject) => subjectHash(subject);
}
