import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/data/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

void main() {
  late CollapsedSectionsRepository repository;

  setUp(() {
    repository = CollapsedSectionsRepository();
  });

  test('reads no collapsed section on a device that stored none', () async {
    expect(await repository.read(), isEmpty);
  });

  test('stores the collapsed sections on the device and reads them back', () async {
    await repository.write({'group:Sales', 'other'});

    expect(await CollapsedSectionsRepository().read(), {'group:Sales', 'other'});
    expect(StorageKeys.connectionSectionsCollapsed.scope, StorageScope.device);
  });

  test('throws a FormatException for a stored value of another type', () async {
    await AppLocalStorage().save(StorageKeys.connectionSectionsCollapsed.key, 'group:Sales');

    expect(repository.read, throwsFormatException);
  });

  test('throws when the device refuses the write', () async {
    final refusing = CollapsedSectionsRepository(storage: _RefusingStorage());

    expect(() => refusing.write({'other'}), throwsStateError);
  });
}

class _RefusingStorage implements AppLocalStorage {
  @override
  Future<bool> save(String key, dynamic value) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
