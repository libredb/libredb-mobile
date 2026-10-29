package org.libredb.mobile

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The native side of `AndroidBiometricHardware` (lib/features/app_lock/data/services/android_biometric_hardware.dart).
 * `local_auth` on Android reports only the strong and weak classes, never the kind, so the lock screen asks here which
 * biometric hardware the device declares. The package manager's feature flags say what the device HAS, not what is
 * enrolled: the Dart side combines this with `local_auth`'s answer that something is enrolled, and stays neutral when
 * the device declares more than one kind. `BiometricManager` is not used: it answers only whether a strength can
 * authenticate, never which kind.
 */
object BiometricHardware {
    const val CHANNEL = "org.libredb.mobile/biometric_hardware"

    // Literals, not PackageManager.FEATURE_FACE and FEATURE_IRIS, which exist from API 29 while minSdk is 26.
    private const val FINGERPRINT = "android.hardware.fingerprint"
    private const val FACE = "android.hardware.biometrics.face"
    private const val IRIS = "android.hardware.biometrics.iris"

    /** The kind ids the device declares, in a fixed order. [has] answers whether the device declares a feature. */
    fun kinds(has: (String) -> Boolean): List<String> =
        listOf("fingerprint" to FINGERPRINT, "face" to FACE, "iris" to IRIS)
            .filter { (_, feature) -> has(feature) }
            .map { (kind, _) -> kind }

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "kinds") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val manager = context.packageManager
                result.success(kinds { manager.hasSystemFeature(it) })
            } catch (error: Exception) {
                result.error("kinds_failed", error.javaClass.simpleName, null)
            }
        }
    }
}
