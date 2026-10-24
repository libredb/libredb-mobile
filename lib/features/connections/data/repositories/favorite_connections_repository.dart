import 'dart:convert';

import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// Keeps the favorites of every subject in the device preferences, under [StorageKeys.connectionFavorites], as one
/// JSON object: `{"<subject>": {"starred": ["seed:a"], "recent": ["seed:b"]}}`.
class FavoriteConnectionsRepository implements IFavoriteConnectionsRepository {
  FavoriteConnectionsRepository({AppLocalStorage? storage}) : _storage = storage ?? AppLocalStorage();

  static final _log = AppLogger.getLogger('FavoriteConnectionsRepository');

  final AppLocalStorage _storage;

  static final _key = StorageKeys.connectionFavorites.key;

  @override
  Future<ConnectionFavorites> read(String subject) async {
    final entry = (await _readAll())[subject];
    return switch (entry) {
      null => ConnectionFavorites.empty,
      {'starred': final Object? starred, 'recent': final Object? recent} => ConnectionFavorites(
        starred: _ids(starred, 'starred').toSet(),
        recent: _ids(recent, 'recent'),
      ),
      _ => throw FormatException('$_key holds an entry that is not {starred, recent}: ${entry.runtimeType}'),
    };
  }

  @override
  Future<void> write(String subject, ConnectionFavorites favorites) async {
    final all = await _readAll();
    all[subject] = {'starred': favorites.starred.toList()..sort(), 'recent': favorites.recent};
    await _save(all);
  }

  /// A stored value that cannot be read is removed: it may hold the subject's favorites, and keeping it would leave
  /// 'Remove my data' failing on every retry.
  @override
  Future<void> clear(String subject) async {
    final Map<String, Object?> all;
    try {
      all = await _readAll();
    } on FormatException catch (e) {
      _log.warn('{} cannot be read and is removed: {}', [_key, e.message]);
      return clearAll();
    }
    if (all.remove(subject) == null) return;
    if (all.isEmpty) return clearAll();
    await _save(all);
  }

  @override
  Future<void> clearAll() async {
    final removed = await _storage.remove(_key);
    if (!removed) throw StateError('the device refused to remove $_key');
  }

  Future<Map<String, Object?>> _readAll() async {
    final stored = await _storage.read(_key);
    if (stored == null) return {};
    if (stored is! String) throw FormatException('$_key is not a string: ${stored.runtimeType}');
    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, Object?>) throw FormatException('$_key is not a JSON object: ${decoded.runtimeType}');
    return decoded;
  }

  Future<void> _save(Map<String, Object?> all) async {
    final saved = await _storage.save(_key, jsonEncode(all));
    if (!saved) throw StateError('the device refused to store $_key');
  }

  static List<String> _ids(Object? value, String field) => switch (value) {
    final List<Object?> ids when ids.every((id) => id is String) => ids.cast<String>(),
    _ => throw FormatException('$_key holds $field that is not a list of strings: ${value.runtimeType}'),
  };
}
