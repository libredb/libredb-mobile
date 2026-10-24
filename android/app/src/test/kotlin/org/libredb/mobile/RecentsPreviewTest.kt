package org.libredb.mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** When [RecentsPreview] turns the recent-apps screenshot off, which `Activity.setRecentsScreenshotEnabled` does. */
class RecentsPreviewTest {
    @Test
    fun hidesThePreviewFromAndroid13() {
        val calls = mutableListOf<Boolean>()

        assertTrue(RecentsPreview.apply(sdkInt = 33, hidden = true) { calls.add(it) })
        assertTrue(RecentsPreview.apply(sdkInt = 36, hidden = false) { calls.add(it) })

        // The screenshot is enabled when the preview is not hidden.
        assertEquals(listOf(false, true), calls)
    }

    @Test
    fun answersFalseBelowAndroid13WhichHasNoSwitch() {
        val calls = mutableListOf<Boolean>()

        assertFalse(RecentsPreview.apply(sdkInt = 32, hidden = true) { calls.add(it) })
        assertFalse(RecentsPreview.apply(sdkInt = 26, hidden = true) { calls.add(it) })

        assertEquals(emptyList<Boolean>(), calls)
    }
}
