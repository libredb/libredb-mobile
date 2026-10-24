import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/recents_preview.dart';

/// [IRecentsPreview] through a method channel that `MainActivity` answers with
/// `Activity.setRecentsScreenshotEnabled`, which Android 13 (API 33) added; below 13 it answers false.
///
/// iOS has no such switch, so on iOS this answers false without a call.
class ChannelRecentsPreview implements IRecentsPreview {
  const ChannelRecentsPreview();

  static const channel = MethodChannel('org.libredb.mobile/recents_preview');

  @override
  Future<bool> setHidden(bool hidden) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final applied = await channel.invokeMethod<bool>('setHidden', {'hidden': hidden});
    if (applied == null) throw StateError('MainActivity answered no result to setHidden');
    return applied;
  }
}
