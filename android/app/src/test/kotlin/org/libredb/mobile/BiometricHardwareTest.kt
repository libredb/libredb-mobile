package org.libredb.mobile

import org.junit.Assert.assertEquals
import org.junit.Test

/** Which biometric kinds [BiometricHardware] names from the package manager's feature flags. */
class BiometricHardwareTest {
    private fun kinds(vararg features: String) = BiometricHardware.kinds { it in features }

    @Test
    fun namesEachKindTheDeviceDeclares() {
        assertEquals(listOf("fingerprint"), kinds("android.hardware.fingerprint"))
        assertEquals(listOf("face"), kinds("android.hardware.biometrics.face"))
        assertEquals(listOf("iris"), kinds("android.hardware.biometrics.iris"))
    }

    @Test
    fun namesEveryKindOfADeviceWithSeveral() {
        assertEquals(
            listOf("fingerprint", "face", "iris"),
            kinds(
                "android.hardware.biometrics.iris",
                "android.hardware.biometrics.face",
                "android.hardware.fingerprint",
            ),
        )
    }

    @Test
    fun namesNothingWhenTheDeviceDeclaresNoBiometricHardware() {
        assertEquals(emptyList<String>(), kinds("android.hardware.camera"))
    }
}
