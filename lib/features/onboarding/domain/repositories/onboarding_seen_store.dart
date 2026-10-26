/// Whether this device has shown the introduction.
///
/// It belongs to the device, not to an account: the introduction runs before anyone signs in, so there is no subject
/// to key it to, and a sign-out must not bring it back for the next person holding the same phone.
abstract class IOnboardingSeenStore {
  /// Whether the introduction has been shown on this device.
  ///
  /// An implementation answers `true` for anything it cannot read as a definite "no". A storage hiccup must never
  /// trap a returning user in the introduction on every launch, which is the mirror of the session's rule that
  /// unauthenticated is the safe default.
  Future<bool> read();

  /// Records that the introduction has been shown. Writing twice is not an error.
  Future<void> write();
}
