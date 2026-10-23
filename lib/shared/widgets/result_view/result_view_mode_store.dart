/// How a result shows its rows: a card per row, or a table.
enum ResultViewMode { cards, table }

/// The view mode of every result on this device, the same for every account, since a view mode holds no user data.
///
/// A convenience only: `ResultViewModeCubit` shows cards when the stored mode cannot be read, and keeps a choice the
/// device refuses to store until the app closes.
abstract interface class IResultViewModeStore {
  /// The stored mode, or null for none; throws when the stored value cannot be read.
  Future<ResultViewMode?> read();

  /// Stores [mode]; throws when the device refuses the write.
  Future<void> write(ResultViewMode mode);
}
