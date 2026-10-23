import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/result_view_mode_preferences.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';

void main() {
  test('reads no mode on a device that stored none', () async {
    expect(await ResultViewModePreferences().read(), isNull);
  });

  test('keeps the mode for the device, outliving the session, and reads it back', () async {
    await ResultViewModePreferences().write(ResultViewMode.table);

    expect(await ResultViewModePreferences().read(), ResultViewMode.table);
    expect(await AppLocalStorage().read(StorageKeys.resultViewMode.key), 'table');
    expect(StorageKeys.resultViewMode.scope, StorageScope.device);
  });

  test('throws a FormatException for a stored value that is not a mode', () async {
    await AppLocalStorage().save(StorageKeys.resultViewMode.key, 'grid');

    expect(ResultViewModePreferences().read, throwsFormatException);
  });

  test('throws a FormatException for a stored value that is not a string', () async {
    await AppLocalStorage().save(StorageKeys.resultViewMode.key, 1);

    expect(ResultViewModePreferences().read, throwsFormatException);
  });

  test('throws when the device refuses the write', () async {
    expect(() => ResultViewModePreferences(storage: _RefusingStorage()).write(ResultViewMode.table), throwsStateError);
  });
}

class _RefusingStorage implements AppLocalStorage {
  @override
  Future<bool> save(String key, dynamic value) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
