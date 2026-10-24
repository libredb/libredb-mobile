import 'dart:convert';

import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_store.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';

/// Keeps the active database of each signed-in user on each server-level connection in the device preferences, under
/// [StorageKeys.activeCatalog], as a JSON object from the SHA-256 of the subject to an object from the connection id
/// to the database, so the subject itself is never stored.
///
/// The value outlives the session, so the next sign-in of the same user runs in the same database, and a second account
/// on the device never reads the first one's.
class ActiveCatalogPreferences implements IActiveCatalogStore {
  ActiveCatalogPreferences({AppLocalStorage? storage}) : _storage = storage ?? AppLocalStorage();

  static final _log = AppLogger.getLogger('ActiveCatalogPreferences');

  final AppLocalStorage _storage;

  static final _key = StorageKeys.activeCatalog.key;

  @override
  Future<String?> read(String subject, String connectionId) async =>
      (await _readAll())[subjectHash(subject)]?[connectionId];

  @override
  Future<void> write(String subject, String connectionId, String catalog) async {
    final all = await _readOrReplace();
    (all[subjectHash(subject)] ??= {})[connectionId] = catalog;
    await _save(all);
  }

  /// A stored value that cannot be read is removed, as [write] replaces it: it is a convenience only, and leaving it
  /// would keep the subject's databases on the device.
  @override
  Future<void> clear(String subject) async {
    final stored = await _storage.read(_key);
    if (stored == null) return;
    final all = await _readOrReplace();
    final forgotten = all.remove(subjectHash(subject)) != null;
    if (all.isNotEmpty) {
      if (forgotten) await _save(all);
      return;
    }
    final removed = await _storage.remove(_key);
    if (!removed) throw StateError('the device refused to remove $_key');
  }

  Future<Map<String, Map<String, String>>> _readOrReplace() async {
    try {
      return await _readAll();
    } on FormatException catch (e) {
      _log.warn('{} cannot be read and is replaced: {}', [_key, e.message]);
      return {};
    }
  }

  Future<void> _save(Map<String, Map<String, String>> all) async {
    final saved = await _storage.save(_key, jsonEncode(all));
    if (!saved) throw StateError('the device refused to store $_key');
  }

  Future<Map<String, Map<String, String>>> _readAll() async {
    final stored = await _storage.read(_key);
    if (stored == null) return {};
    if (stored is! String) throw FormatException('$_key is not a string: ${stored.runtimeType}');
    final Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      throw FormatException('$_key is not JSON');
    }
    if (decoded is! Map<String, Object?> ||
        decoded.values.any(
          (catalogs) => catalogs is! Map<String, Object?> || catalogs.values.any((catalog) => catalog is! String),
        )) {
      throw FormatException('$_key is not an object of databases by connection');
    }
    return {
      for (final MapEntry(:key, :value) in decoded.entries) key: (value as Map<String, Object?>).cast<String, String>(),
    };
  }
}
