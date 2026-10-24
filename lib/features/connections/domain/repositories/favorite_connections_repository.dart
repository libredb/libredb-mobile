import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';

/// The starred and recently opened connections, kept on the device per signed-in subject (the identity provider's
/// `sub`), so two accounts on one phone never share them.
///
/// [clear] and [clearAll] are for the user's 'Remove my data' (M6-07, #34).
abstract interface class IFavoriteConnectionsRepository {
  /// The favorites of [subject], empty when it stored none; throws when the stored value cannot be read.
  Future<ConnectionFavorites> read(String subject);

  /// Replaces the favorites of [subject] and keeps those of every other subject; throws when the stored value cannot
  /// be read, which it then leaves as it is, or when the device refuses the write.
  Future<void> write(String subject, ConnectionFavorites favorites);

  /// Removes the favorites of [subject], or the whole stored value when it cannot be read; throws when the device
  /// refuses.
  Future<void> clear(String subject);

  /// Removes the favorites of every subject; throws when the device refuses.
  Future<void> clearAll();
}
