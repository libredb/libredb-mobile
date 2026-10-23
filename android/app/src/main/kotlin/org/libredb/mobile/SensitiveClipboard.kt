package org.libredb.mobile

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The native side of `SensitiveClipboard` (lib/shared/utils/sensitive_clipboard.dart): a copied result or key value is
 * marked with [ClipDescription.EXTRA_IS_SENSITIVE] on Android 13 and later, so the system's clipboard preview hides it.
 * Android below 13 shows no preview, so the clip is plain there. No error carries the copied text.
 */
object SensitiveClipboard {
    const val CHANNEL = "org.libredb.mobile/sensitive_clipboard"

    /** API 33, Android 13: the first level that shows a clipboard preview and reads the sensitive flag. */
    private const val FIRST_PREVIEW_SDK = 33

    fun marksSensitive(sdkInt: Int, sensitive: Boolean): Boolean = sensitive && sdkInt >= FIRST_PREVIEW_SDK

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "copy") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val text = call.argument<String>("text")
            if (text == null) {
                result.error("bad_arguments", "copy needs a text", null)
                return@setMethodCallHandler
            }
            try {
                copy(context, text, call.argument<Boolean>("sensitive") == true)
                result.success(null)
            } catch (error: Exception) {
                // The class name only: a message could quote the clip.
                result.error("copy_failed", error.javaClass.simpleName, null)
            }
        }
    }

    private fun copy(context: Context, text: String, sensitive: Boolean) {
        val manager = context.getSystemService(ClipboardManager::class.java)
            ?: throw IllegalStateException("no clipboard service")
        val clip = ClipData.newPlainText("", text)
        if (marksSensitive(Build.VERSION.SDK_INT, sensitive)) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
        }
        manager.setPrimaryClip(clip)
    }
}
