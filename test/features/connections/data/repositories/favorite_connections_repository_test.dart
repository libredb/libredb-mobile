import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/data/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

void main() {
  const alice = 'subject-alice';
  const bob = 'subject-bob';

  late _MemoryStorage storage;
  late FavoriteConnectionsRepository repository;

  setUp(() {
    storage = _MemoryStorage();
    repository = FavoriteConnectionsRepository(storage: storage);
  });

  test('reads no favorites and no recent connections for a subject that stored none', () async {
    expect(await repository.read(alice), ConnectionFavorites.empty);
  });

  test('stores the favorites of a subject on the device, in one device key, and reads them back', () async {
    const favorites = ConnectionFavorites(starred: {'seed:b', 'seed:a'}, recent: ['seed:c', 'seed:a']);

    await repository.write(alice, favorites);

    expect(await FavoriteConnectionsRepository(storage: storage).read(alice), favorites);
    expect(storage.values.keys, [StorageKeys.connectionFavorites.key]);
    expect(StorageKeys.connectionFavorites.scope, StorageScope.device);
  });

  test('keeps the favorites of each subject apart', () async {
    await repository.write(alice, const ConnectionFavorites(starred: {'seed:a'}, recent: ['seed:a']));
    await repository.write(bob, const ConnectionFavorites(starred: {'seed:b'}, recent: []));

    expect(await repository.read(alice), const ConnectionFavorites(starred: {'seed:a'}, recent: ['seed:a']));
    expect(await repository.read(bob), const ConnectionFavorites(starred: {'seed:b'}, recent: []));
  });

  test('clear removes one subject and keeps the others', () async {
    await repository.write(alice, const ConnectionFavorites(starred: {'seed:a'}, recent: []));
    await repository.write(bob, const ConnectionFavorites(starred: {'seed:b'}, recent: []));

    await repository.clear(alice);

    expect(await repository.read(alice), ConnectionFavorites.empty);
    expect(await repository.read(bob), const ConnectionFavorites(starred: {'seed:b'}, recent: []));
  });

  test('clear of the last subject and clearAll remove the device key', () async {
    await repository.write(alice, const ConnectionFavorites(starred: {'seed:a'}, recent: []));
    await repository.clear(alice);
    expect(storage.values, isEmpty);

    await repository.write(alice, const ConnectionFavorites(starred: {'seed:a'}, recent: []));
    await repository.write(bob, const ConnectionFavorites(starred: {'seed:b'}, recent: []));
    await repository.clearAll();
    expect(storage.values, isEmpty);
  });

  group('throws instead of reading', () {
    for (final (name, stored) in [
      ('a value of another type', ['seed:a']),
      ('text that is no JSON', '{"subject-alice":'),
      ('JSON that is no object', '["seed:a"]'),
      ('a subject entry that is no object', '{"subject-alice": ["seed:a"]}'),
      ('starred ids that are not strings', '{"subject-alice": {"starred": [1], "recent": []}}'),
      ('recent ids that are no list', '{"subject-alice": {"starred": [], "recent": "seed:a"}}'),
      ('an entry without its starred ids', '{"subject-alice": {"recent": []}}'),
    ]) {
      test(name, () async {
        storage.values[StorageKeys.connectionFavorites.key] = stored;

        expect(() => repository.read(alice), throwsFormatException);
      });
    }
  });

  group('clear removes a stored value it cannot read, so Remove my data completes', () {
    for (final (name, stored) in [
      ('a value of another type', ['seed:a']),
      ('text that is not json', 'not json'),
      ('JSON that is no object', '["seed:a"]'),
    ]) {
      test(name, () async {
        storage.values[StorageKeys.connectionFavorites.key] = stored;

        await repository.clear(alice);

        expect(storage.values, isEmpty);
      });
    }

    test('and throws when the device refuses to remove it', () async {
      storage.values[StorageKeys.connectionFavorites.key] = 'not json';
      storage.refuses = true;

      await expectLater(() => repository.clear(alice), throwsStateError);
    });
  });

  test('a write over a stored value it cannot read throws and leaves the value as it was', () async {
    storage.values[StorageKeys.connectionFavorites.key] = '["seed:a"]';

    await expectLater(
      () => repository.write(alice, const ConnectionFavorites(starred: {'seed:b'}, recent: [])),
      throwsFormatException,
    );
    expect(storage.values[StorageKeys.connectionFavorites.key], '["seed:a"]');
  });

  test('throws when the device refuses the write or the removal', () async {
    await repository.write(alice, const ConnectionFavorites(starred: {'seed:a'}, recent: []));
    storage.refuses = true;

    await expectLater(() => repository.write(bob, ConnectionFavorites.empty), throwsStateError);
    await expectLater(() => repository.clear(alice), throwsStateError);
    await expectLater(repository.clearAll, throwsStateError);
  });

  test('reads and writes through the device preferences by default', () async {
    await FavoriteConnectionsRepository().write(alice, const ConnectionFavorites(starred: {'seed:a'}, recent: []));

    expect(
      await FavoriteConnectionsRepository().read(alice),
      const ConnectionFavorites(starred: {'seed:a'}, recent: []),
    );
  });
}

/// An in-memory device store, which refuses every write and removal once [refuses] is set.
class _MemoryStorage implements AppLocalStorage {
  final values = <String, Object?>{};
  var refuses = false;

  @override
  Future<dynamic> read(String key) async => values[key];

  @override
  Future<bool> save(String key, dynamic value) async {
    if (refuses) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (refuses) return false;
    values.remove(key);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
