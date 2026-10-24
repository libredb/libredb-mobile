package org.libredb.mobile

import android.app.Activity
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The native side of `ChannelRecentsPreview` (lib/features/app_lock/data/services/channel_recents_preview.dart): while
 * the app lock is on, the recent-apps screen shows no screenshot of the app, through
 * `Activity.setRecentsScreenshotEnabled`, which Android 13 (API 33) added. Below 13 it answers false and the Dart side
 * covers the preview with `FLAG_SECURE` while the app is away.
 */
object RecentsPreview {
    const val CHANNEL = "org.libredb.mobile/recents_preview"

    /**
     * Hides the preview ([hidden]) or shows it again through [setScreenshotEnabled] when [sdkInt] has the switch, and
     * answers whether it did.
     */
    fun apply(sdkInt: Int, hidden: Boolean, setScreenshotEnabled: (Boolean) -> Unit): Boolean {
        if (sdkInt < Build.VERSION_CODES.TIRAMISU) return false
        setScreenshotEnabled(!hidden)
        return true
    }

    fun register(messenger: BinaryMessenger, activity: Activity) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "setHidden") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val hidden = call.argument<Boolean>("hidden")
            if (hidden == null) {
                result.error("bad_arguments", "setHidden needs hidden", null)
                return@setMethodCallHandler
            }
            result.success(
                apply(Build.VERSION.SDK_INT, hidden) { enabled ->
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        activity.setRecentsScreenshotEnabled(enabled)
                    }
                },
            )
        }
    }
}
