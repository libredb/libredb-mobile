package org.libredb.mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** What [SecureWindow] answers the Dart side: the `FLAG_SECURE` state it reads back from the window, or a failure. */
class SecureWindowTest {
    /** A window's flag; [holds] false makes it ignore a set, as a window that refuses the flag would. */
    private class FakeFlag(var set: Boolean = false, private val holds: Boolean = true) : SecureWindow.Flag {
        override fun add() {
            if (holds) set = true
        }

        override fun clear() {
            set = false
        }

        override fun isSet(): Boolean = set
    }

    @Test
    fun setsTheFlagAndReportsItSet() {
        val flag = FakeFlag()

        assertEquals(SecureWindow.Answer.FlagState(true), SecureWindow.answer("setSecure", true, flag))
        assertTrue(flag.set)
    }

    @Test
    fun clearsTheFlagAndReportsItClear() {
        val flag = FakeFlag(set = true)

        assertEquals(SecureWindow.Answer.FlagState(false), SecureWindow.answer("setSecure", false, flag))
        assertEquals(false, flag.set)
    }

    // The answer is read back from the window, never the request echoed, so a flag that did not take shows.
    @Test
    fun reportsTheFlagClearWhenTheWindowDidNotTakeIt() {
        assertEquals(
            SecureWindow.Answer.FlagState(false),
            SecureWindow.answer("setSecure", true, FakeFlag(holds = false)),
        )
    }

    @Test
    fun failsWithoutAWindow() {
        val answer = SecureWindow.answer("setSecure", true, null)

        assertEquals("no_window", (answer as SecureWindow.Answer.Failure).code)
    }

    @Test
    fun failsWhenTheWindowThrows() {
        val throwing = object : SecureWindow.Flag {
            override fun add() = throw IllegalStateException("window gone")

            override fun clear() = Unit

            override fun isSet() = false
        }

        val answer = SecureWindow.answer("setSecure", true, throwing) as SecureWindow.Answer.Failure

        assertEquals("set_secure_failed", answer.code)
        assertEquals("IllegalStateException", answer.message)
    }

    @Test
    fun refusesACallWithoutTheFlagArgument() {
        val flag = FakeFlag()

        val answer = SecureWindow.answer("setSecure", null, flag)

        assertEquals("bad_arguments", (answer as SecureWindow.Answer.Failure).code)
        assertEquals(false, flag.set)
    }

    @Test
    fun answersAnUnknownMethodAsNotImplemented() {
        assertEquals(SecureWindow.Answer.NotImplemented, SecureWindow.answer("protectDataLeakageOn", true, FakeFlag()))
    }
}
