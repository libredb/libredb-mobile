import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/storage/active_catalog_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

void main() {
  const first = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';
  const second = 'b0d7c4e1-1111-4222-8333-944455556666';
  const server = 'seed:dev-postgres-server';
  const other = 'seed:other-server';

  late ActiveCatalogPreferences store;

  setUp(() => store = ActiveCatalogPreferences());

  Future<Object?> stored() => AppLocalStorage().read(StorageKeys.activeCatalog.key);

  test('reads no database on a device that stored none', () async {
    expect(await store.read(first, server), isNull);
  });

  test('keeps one database per subject and connection, outliving the session, and reads each back', () async {
    await store.write(first, server, 'archive');
    await store.write(first, other, 'app');
    await store.write(second, server, 'postgres');

    final again = ActiveCatalogPreferences();
    expect(await again.read(first, server), 'archive');
    expect(await again.read(first, other), 'app');
    expect(await again.read(second, server), 'postgres');
    expect(await again.read(second, other), isNull);
    expect(StorageKeys.activeCatalog.scope, StorageScope.device);
  });

  test('replaces the database of a connection', () async {
    await store.write(first, server, 'archive');
    await store.write(first, server, 'app');

    expect(await store.read(first, server), 'app');
  });

  test('never stores the subject itself', () async {
    await store.write(first, server, 'archive');

    expect(await stored(), isA<String>().having((value) => value, 'value', isNot(contains(first))));
  });

  test('throws a FormatException for a stored value of another shape', () async {
    await AppLocalStorage().save(StorageKeys.activeCatalog.key, '{"x":"archive"}');

    expect(() => store.read(first, server), throwsFormatException);
  });

  test('replaces a stored value of another shape on the next write', () async {
    await AppLocalStorage().save(StorageKeys.activeCatalog.key, 'not json');

    await store.write(first, server, 'archive');

    expect(await store.read(first, server), 'archive');
  });

  test('throws when the device refuses the write', () async {
    final refusing = ActiveCatalogPreferences(storage: _RefusingStorage());

    expect(() => refusing.write(first, server, 'archive'), throwsStateError);
  });

  group('clear', () {
    test('removes only the databases of that subject', () async {
      await store.write(first, server, 'archive');
      await store.write(first, other, 'app');
      await store.write(second, server, 'postgres');

      await store.clear(first);

      expect(await store.read(first, server), isNull);
      expect(await store.read(first, other), isNull);
      expect(await store.read(second, server), 'postgres');
    });

    test('removes the key once no subject is left', () async {
      await store.write(first, server, 'archive');

      await store.clear(first);

      expect(await stored(), isNull);
    });

    test('leaves the device as it was when that subject stored nothing', () async {
      await store.write(second, server, 'postgres');

      await store.clear(first);

      expect(await store.read(second, server), 'postgres');
    });

    test('does nothing on a device that stored nothing', () async {
      await store.clear(first);

      expect(await stored(), isNull);
    });

    test('removes a stored value of another shape, as a write replaces it', () async {
      await AppLocalStorage().save(StorageKeys.activeCatalog.key, 'not json');

      await store.clear(first);

      expect(await stored(), isNull);
    });

    test('throws when the device refuses to store what is left', () async {
      await store.write(first, server, 'archive');
      await store.write(second, server, 'postgres');
      final refusing = ActiveCatalogPreferences(storage: _RefusingStorage(stored: await stored()));

      expect(() => refusing.clear(first), throwsStateError);
    });

    test('throws when the device refuses to remove the key', () async {
      await store.write(first, server, 'archive');
      final refusing = ActiveCatalogPreferences(storage: _RefusingStorage(stored: await stored()));

      expect(() => refusing.clear(first), throwsStateError);
    });
  });
}

class _RefusingStorage implements AppLocalStorage {
  _RefusingStorage({this.stored});

  /// What the device answers for every key.
  final Object? stored;

  @override
  Future<dynamic> read(String key) async => stored;

  @override
  Future<bool> save(String key, dynamic value) async => false;

  @override
  Future<bool> remove(String key) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
