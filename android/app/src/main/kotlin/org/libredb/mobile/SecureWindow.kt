package org.libredb.mobile

import android.app.Activity
import android.view.Window
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The native side of `ScreenCapturePlatform` (lib/core/security/screen_capture_platform.dart): sets or clears
 * `FLAG_SECURE` on the activity's window and answers whether the flag is set afterwards, read back from the window, so
 * the Dart side never assumes a protection that did not take. Without a window, or when the window throws, it answers
 * an error instead.
 */
object SecureWindow {
    const val CHANNEL = "org.libredb.mobile/screen_capture"

    /** The `FLAG_SECURE` calls on a window, narrow so a JVM test runs [answer] without one. */
    interface Flag {
        fun add()

        fun clear()

        fun isSet(): Boolean
    }

    /** What the channel answers a call. */
    sealed interface Answer {
        /** Whether `FLAG_SECURE` is set on the window after the call. */
        data class FlagState(val isSet: Boolean) : Answer

        data class Failure(val code: String, val message: String) : Answer

        data object NotImplemented : Answer
    }

    /** Runs [method] with its `secure` argument [secure] on [flag], the window's flag, or null without a window. */
    fun answer(method: String, secure: Boolean?, flag: Flag?): Answer {
        if (method != "setSecure") return Answer.NotImplemented
        if (secure == null) return Answer.Failure("bad_arguments", "setSecure needs secure")
        if (flag == null) return Answer.Failure("no_window", "the activity has no window")
        return try {
            if (secure) flag.add() else flag.clear()
            Answer.FlagState(flag.isSet())
        } catch (error: Exception) {
            Answer.Failure("set_secure_failed", error.javaClass.simpleName)
        }
    }

    fun register(messenger: BinaryMessenger, activity: Activity) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            val flag = activity.window?.let(::WindowFlag)
            when (val answer = answer(call.method, call.argument<Boolean>("secure"), flag)) {
                is Answer.FlagState -> result.success(answer.isSet)
                is Answer.Failure -> result.error(answer.code, answer.message, null)
                Answer.NotImplemented -> result.notImplemented()
            }
        }
    }

    private class WindowFlag(private val window: Window) : Flag {
        override fun add() = window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        override fun clear() = window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)

        override fun isSet(): Boolean = window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
    }
}
