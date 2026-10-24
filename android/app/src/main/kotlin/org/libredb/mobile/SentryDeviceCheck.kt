package org.libredb.mobile

import android.content.Intent

/**
 * The native crash of the Sentry device check in docs/crash-reporting.md: a release build that carries
 * `--dart-define=SENTRY_DEVICE_CHECK=true` (BuildConfig.SENTRY_DEVICE_CHECK, written by android/app/build.gradle.kts
 * for a lib/main/main_prod.dart build only) crashes when it is started with the boolean extra [EXTRA]:
 *
 * `adb shell am start -S -n org.libredb.mobile/.MainActivity --ez sentry_device_check_native_crash true`
 *
 * The crash carries an email address and a token, which [NativeSentryScrubber] must mask; sentry-android sends it on
 * the next start. Every other build ignores the extra.
 */
object SentryDeviceCheck {
    const val EXTRA = "sentry_device_check_native_crash"

    /** A JWT-shaped token for the check. It signs nothing. */
    const val TOKEN = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJkZXZpY2UtY2hlY2sifQ.devicecheckonly"

    /**
     * The crash to throw: one only when the build carries the define ([defined]) and the intent asks ([asked]).
     * [asked] runs only when [defined] is true, so in a build without the define, where [defined] is the constant
     * false, the compiler drops the read of the extra.
     */
    inline fun nativeCrash(defined: Boolean, asked: () -> Boolean): RuntimeException? =
        if (defined && asked()) crash() else null

    /** The crash of the check, with an email address and a token for the scrubber to mask. */
    fun crash() =
        RuntimeException("LibreDB Sentry device check: native crash for device.check@example.com with Bearer $TOKEN")

    /** Throws the crash when the build carries the define and [intent] asks; the extra is read only with the define. */
    fun crashIfAsked(intent: Intent?) {
        nativeCrash(BuildConfig.SENTRY_DEVICE_CHECK) { intent?.getBooleanExtra(EXTRA, false) == true }?.let { throw it }
    }
}
