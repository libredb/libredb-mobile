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
}
