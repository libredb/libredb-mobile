package org.libredb.mobile

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Which clips [SensitiveClipboard] marks with `ClipDescription.EXTRA_IS_SENSITIVE`. */
class SensitiveClipboardTest {
    @Test
    fun marksASensitiveClipFromAndroid13() {
        assertTrue(SensitiveClipboard.marksSensitive(sdkInt = 33, sensitive = true))
        assertTrue(SensitiveClipboard.marksSensitive(sdkInt = 36, sensitive = true))
    }

    @Test
    fun copiesPlainlyBelowAndroid13WhichShowsNoPreview() {
        assertFalse(SensitiveClipboard.marksSensitive(sdkInt = 32, sensitive = true))
        assertFalse(SensitiveClipboard.marksSensitive(sdkInt = 26, sensitive = true))
    }

    @Test
    fun neverMarksAClipTheCallerDidNotAskFor() {
        assertFalse(SensitiveClipboard.marksSensitive(sdkInt = 33, sensitive = false))
    }
}
