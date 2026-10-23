/// The connection each signed-in user had open last on this device, by the identity provider's subject.
///
/// A convenience only: the caller treats a failed read as no connection and a refused write as nothing stored.
abstract interface class IActiveConnectionStore {
  /// The connection id stored for [subject], or null for none; throws when the stored value cannot be read.
  Future<String?> read(String subject);

  /// Stores [connectionId] for [subject], or forgets the subject's connection when it is null; throws when the device
  /// refuses the write.
  Future<void> write(String subject, String? connectionId);
}
