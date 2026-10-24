/// Which sections of the connection list the user collapsed on this device, by section key.
abstract interface class ICollapsedSectionsRepository {
  /// The stored keys; throws when the stored value cannot be read.
  Future<Set<String>> read();

  /// Replaces the stored keys; throws when the device refuses the write.
  Future<void> write(Set<String> keys);

  /// Removes the stored keys, which are Studio's environment and group names, for 'Remove my data'; throws when the
  /// device refuses.
  Future<void> clear();
}
