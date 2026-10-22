import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

/// Keeps the collapsed sections in the device preferences, under [StorageKeys.connectionSectionsCollapsed].
class CollapsedSectionsRepository implements ICollapsedSectionsRepository {
  CollapsedSectionsRepository({AppLocalStorage? storage}) : _storage = storage ?? AppLocalStorage();

  final AppLocalStorage _storage;

  static final _key = StorageKeys.connectionSectionsCollapsed.key;

  @override
  Future<Set<String>> read() async {
    final stored = await _storage.read(_key);
    return switch (stored) {
      null => <String>{},
      final List<Object?> keys when keys.every((key) => key is String) => keys.cast<String>().toSet(),
      _ => throw FormatException('$_key is not a list of strings: ${stored.runtimeType}'),
    };
  }

  @override
  Future<void> write(Set<String> keys) async {
    final saved = await _storage.save(_key, keys.toList()..sort());
    if (!saved) throw StateError('the device refused to store $_key');
  }
}
