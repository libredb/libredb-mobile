import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/storage/active_connection_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

void main() {
  const first = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';
  const second = 'b0d7c4e1-1111-4222-8333-944455556666';

  late ActiveConnectionPreferences store;

  setUp(() => store = ActiveConnectionPreferences());

  Future<Object?> stored() => AppLocalStorage().read(StorageKeys.activeConnection.key);

  test('reads no connection on a device that stored none', () async {
    expect(await store.read(first), isNull);
  });

  test('keeps one connection per subject, outliving the session, and reads each back', () async {
    await store.write(first, 'seed:sales');
    await store.write(second, 'seed:billing');

    final again = ActiveConnectionPreferences();
    expect(await again.read(first), 'seed:sales');
    expect(await again.read(second), 'seed:billing');
    expect(StorageKeys.activeConnection.scope, StorageScope.device);
  });

  test('never stores the subject itself', () async {
    await store.write(first, 'seed:sales');

    expect(await stored(), isA<String>().having((value) => value, 'value', isNot(contains(first))));
  });

  test('forgets the connection of one subject and keeps the others', () async {
    await store.write(first, 'seed:sales');
    await store.write(second, 'seed:billing');
    await store.write(first, null);

    expect(await store.read(first), isNull);
    expect(await store.read(second), 'seed:billing');
  });

  test('throws a FormatException for a stored value of another shape', () async {
    await AppLocalStorage().save(StorageKeys.activeConnection.key, '["seed:sales"]');

    expect(() => store.read(first), throwsFormatException);
  });

  test('replaces a stored value of another shape on the next write', () async {
    await AppLocalStorage().save(StorageKeys.activeConnection.key, 'not json');

    await store.write(first, 'seed:sales');

    expect(await store.read(first), 'seed:sales');
  });

  test('throws when the device refuses the write', () async {
    final refusing = ActiveConnectionPreferences(storage: _RefusingStorage());

    expect(() => refusing.write(first, 'seed:sales'), throwsStateError);
  });
}

class _RefusingStorage implements AppLocalStorage {
  @override
  Future<dynamic> read(String key) async => null;

  @override
  Future<bool> save(String key, dynamic value) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
