/// The level of the grant a governed Studio resolved a connection for, its `access` field.
///
/// A Studio without governance, and Studio before libredb-studio#1922, sends none.
enum StudioAccess {
  /// Studio refuses every statement that writes, until an administrator raises the grant.
  read,

  /// Studio runs a write, unless the connection itself is read only.
  write,
}
