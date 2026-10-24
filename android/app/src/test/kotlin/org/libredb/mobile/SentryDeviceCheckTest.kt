package org.libredb.mobile

import io.sentry.SentryEvent
import io.sentry.protocol.SentryException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The native crash of the Sentry device check (docs/crash-reporting.md). */
class SentryDeviceCheckTest {
    @Test
    fun crashesOnlyWhenTheBuildCarriesTheDefineAndTheIntentAsks() {
        assertNull(SentryDeviceCheck.nativeCrash(defined = false, asked = true))
        assertNull(SentryDeviceCheck.nativeCrash(defined = true, asked = false))
        assertTrue(SentryDeviceCheck.nativeCrash(defined = true, asked = true) is RuntimeException)
    }

    // The crash carries an email and a token for the check in Sentry; the native scrubber masks both.
    @Test
    fun crashesWithAnEmailAndATokenThatTheNativeScrubberMasks() {
        val crash = SentryDeviceCheck.nativeCrash(defined = true, asked = true)!!
        assertTrue(crash.message!!.contains("device.check@example.com"))
        val event = SentryEvent().apply { exceptions = listOf(SentryException().apply { value = crash.message }) }

        val scrubbed = NativeSentryScrubber.beforeSend(event)!!.exceptions!![0].value!!

        assertFalse(scrubbed.contains("device.check@example.com"))
        assertFalse(scrubbed.contains(SentryDeviceCheck.TOKEN))
        assertEquals(
            "LibreDB Sentry device check: native crash for [REDACTED_EMAIL] with Bearer [REDACTED_JWT]",
            scrubbed,
        )
    }
}
