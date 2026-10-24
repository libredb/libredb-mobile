/// The app's preview in the recent-apps screen.
abstract interface class IRecentsPreview {
  /// Hides the preview, or shows it again, where the platform has a switch for it (Android 13 and later); answers
  /// whether the platform applied it, false where it has no such switch.
  Future<bool> setHidden(bool hidden);
}
