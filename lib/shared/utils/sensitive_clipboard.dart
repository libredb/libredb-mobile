import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The one way a result or key value reaches the clipboard, through a method channel that `MainActivity` and
/// `AppDelegate` answer.
///
/// On Android 13 and later the clip carries `ClipDescription.EXTRA_IS_SENSITIVE`, so the system's preview hides the
/// value; Android below 13 shows no preview and gets a plain clip. On iOS the item expires after [iosExpiry] and is
/// local only, so Universal Clipboard does not carry it to the user's other devices.
///
/// A failed copy throws, a `PlatformException` or a `MissingPluginException`, for the caller to show; nothing here
/// logs the text. The source viewer and the copy of a name keep the plain `Clipboard`.
abstract final class SensitiveClipboard {
  static const channel = MethodChannel('org.libredb.mobile/sensitive_clipboard');

  /// How long a copied value stays on the iOS pasteboard.
  static const iosExpiry = Duration(minutes: 2);

  /// Puts [text] on the clipboard, marked as sensitive. Throws an [UnsupportedError] on a platform the app does not
  /// ship on.
  static Future<void> copy(String text) => switch (defaultTargetPlatform) {
    TargetPlatform.android => channel.invokeMethod<void>('copy', {'text': text, 'sensitive': true}),
    TargetPlatform.iOS => channel.invokeMethod<void>('copy', {
      'text': text,
      'expiresInSeconds': iosExpiry.inSeconds,
      'localOnly': true,
    }),
    final platform => Future.error(UnsupportedError('no sensitive clipboard on ${platform.name}')),
  };
}
