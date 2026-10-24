/// The database each signed-in user ran statements in last on each server-level connection, on this device, by the
/// identity provider's subject.
///
/// A convenience only: the caller treats a failed read as no database and a refused write as nothing stored.
abstract interface class IActiveCatalogStore {
  /// The database stored for [subject] on [connectionId], or null for none; throws when the stored value cannot be
  /// read.
  Future<String?> read(String subject, String connectionId);

  /// Stores [catalog] for [subject] on [connectionId]; throws when the device refuses the write.
  Future<void> write(String subject, String connectionId, String catalog);

  /// Forgets every database stored for [subject] and keeps those of every other subject, for 'Remove my data'; throws
  /// when the device refuses the change.
  Future<void> clear(String subject);
}
