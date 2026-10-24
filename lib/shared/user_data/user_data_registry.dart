/// One store that keeps data of a signed-in account on this device, past the session, such as the drafts or the
/// starred connections.
final class UserDataStore {
  const UserDataStore({required this.name, required this.clear});

  /// What the log calls the store; for a value in the device preferences, its `StorageKeys` key. It names no stored
  /// value.
  final String name;

  /// Removes what the store keeps for the account of the identity provider's subject [subject], and leaves every other
  /// account's data; throws when the store cannot remove it.
  final Future<void> Function(String subject) clear;
}

/// Every store that keeps data of a signed-in account on this device, which the user's 'Remove my data' clears.
///
/// `AppDependencies.createUserDataRegistry` lists them, and `test/architecture/user_data_registry_test.dart` fails when
/// a store that keeps per-account data, or a device preference key, is left out.
class UserDataRegistry {
  UserDataRegistry(List<UserDataStore> stores) : stores = List.unmodifiable(stores) {
    final names = stores.map((store) => store.name).toSet();
    if (names.length != stores.length) throw ArgumentError.value(stores.length, 'stores', 'repeat a name');
  }

  /// The stores, in the order they are cleared.
  final List<UserDataStore> stores;
}
