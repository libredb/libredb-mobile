import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';

void main() {
  Future<void> nothing(String subject) async {}

  test('keeps the stores in the order they were given', () {
    final registry = UserDataRegistry([
      UserDataStore(name: 'b', clear: nothing),
      UserDataStore(name: 'a', clear: nothing),
    ]);

    expect(registry.stores.map((store) => store.name), ['b', 'a']);
    expect(() => registry.stores.add(UserDataStore(name: 'c', clear: nothing)), throwsUnsupportedError);
  });

  test('refuses two stores of one name, which the log could not tell apart', () {
    expect(
      () => UserDataRegistry([UserDataStore(name: 'a', clear: nothing), UserDataStore(name: 'a', clear: nothing)]),
      throwsArgumentError,
    );
  });
}
