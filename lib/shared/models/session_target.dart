/// The backend a signed-in session belongs to: LibreDB Studio, or LibreDB Platform for an admin.
///
/// The target is stored with the session's tokens in secure storage at sign-in, as [storedValue], and read back when
/// the app restores the session, so the router, the shell, the sign-out and the HTTP clients never guess it. It holds
/// no credential.
///
/// Each value carries an explicit [storedValue], as `SecureStorageKeys` does, so renaming a value never changes what is
/// stored.
enum SessionTarget {
  studio('studio'),
  platform('platform');

  const SessionTarget(this.storedValue);

  /// What secure storage holds for this target.
  final String storedValue;

  /// The target whose [storedValue] is exactly [value], or null for any other string, the empty string included. A
  /// value is never coerced to a known target: a caller that gets null decides what an unreadable value means.
  static SessionTarget? fromStoredValue(String value) {
    for (final target in values) {
      if (target.storedValue == value) return target;
    }
    return null;
  }
}
