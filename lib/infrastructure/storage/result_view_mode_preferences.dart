import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';

/// Keeps the result view mode in the device preferences, under [StorageKeys.resultViewMode], as the mode's name.
///
/// A device setting: no sign-out removes it, and every account on the device shares it.
class ResultViewModePreferences implements IResultViewModeStore {
  ResultViewModePreferences({AppLocalStorage? storage}) : _storage = storage ?? AppLocalStorage();

  final AppLocalStorage _storage;

  static final _key = StorageKeys.resultViewMode.key;

  @override
  Future<ResultViewMode?> read() async {
    final stored = await _storage.read(_key);
    if (stored == null) return null;
    if (stored is! String) throw FormatException('$_key is not a string: ${stored.runtimeType}');
    for (final mode in ResultViewMode.values) {
      if (mode.name == stored) return mode;
    }
    throw FormatException('$_key is not a view mode: $stored');
  }

  @override
  Future<void> write(ResultViewMode mode) async {
    final saved = await _storage.save(_key, mode.name);
    if (!saved) throw StateError('the device refused to store $_key');
  }
}
