package org.libredb.mobile

import io.sentry.Breadcrumb
import io.sentry.DataCollection
import io.sentry.Hint
import io.sentry.HttpBodyType
import io.sentry.KeyValueCollectionBehavior
import io.sentry.MainEventProcessor
import io.sentry.SentryEvent
import io.sentry.SentryOptions
import io.sentry.android.core.SentryAndroidOptions
import io.sentry.protocol.SdkVersion
import io.sentry.protocol.SentryException
import io.sentry.protocol.User
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** The options the host app starts sentry-android with, built as [NativeSentry.start] builds them. */
class NativeSentryTest {
    private val jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhYmMifQ.signaturepart"

    private fun configured(options: SentryAndroidOptions = SentryAndroidOptions(), proguardUuid: String = "") =
        options.also {
            NativeSentry.configure(
                it,
                dsn = "https://public@example.invalid/1",
                release = "1.0.0+1",
                dist = "1",
                environment = "production",
                proguardUuid = proguardUuid,
            )
        }

    // The id release.yml gives the R8 mapping it uploads to Sentry (-PsentryProguardUuid), which Sentry matches to the
    // proguard debug image of each event.
    @Test
    fun setsTheProguardUuidOfTheUploadedMapping() {
        val options = configured(proguardUuid = "3f2a0c1e-5b7d-4e8f-9a6b-1c2d3e4f5a6b")

        assertEquals("3f2a0c1e-5b7d-4e8f-9a6b-1c2d3e4f5a6b", options.proguardUuid)
    }

    // A build without -PsentryProguardUuid, such as a local build, sends no proguard debug image.
    @Test
    fun leavesTheProguardUuidUnsetWithoutOne() {
        assertNull(configured().proguardUuid)
    }

    @Test
    fun installsABeforeSendThatScrubsTheEventAndTagsItsOrigin() {
        val options = configured()
        val event = SentryEvent().apply {
            sdk = SdkVersion("sentry.java.android.flutter", "8.61.0")
            exceptions = listOf(SentryException().apply { value = "user jane.doe@example.com token $jwt" })
        }

        val sent = options.beforeSend!!.execute(event, Hint())!!

        assertEquals("user [REDACTED_EMAIL] token [REDACTED_JWT]", sent.exceptions!![0].value)
        assertEquals("android", sent.getTag("event.origin"))
    }

    @Test
    fun installsABeforeBreadcrumbThatScrubsTheBreadcrumb() {
        val options = configured()
        val crumb = Breadcrumb("user jane.doe@example.com").apply { setData("email", "jane.doe@example.com") }

        val kept = options.beforeBreadcrumb!!.execute(crumb, Hint())!!

        assertEquals("user [REDACTED_EMAIL]", kept.message)
        assertEquals("[REDACTED_EMAIL]", kept.data["email"])
    }

    // sentry_flutter passes its Dart timeouts of 5 seconds to the native SDK, whose defaults are 30 seconds.
    @Test
    fun setsTheOptionsThatSentryFlutterWouldPass() {
        val options = configured()

        assertEquals("https://public@example.invalid/1", options.dsn)
        assertEquals("1.0.0+1", options.release)
        assertEquals("1", options.dist)
        assertEquals("production", options.environment)
        assertEquals(5000, options.connectionTimeoutMillis)
        assertEquals(5000, options.readTimeoutMillis)
        assertTrue(options.isEnableScopeSync)
        assertFalse(options.isEnableAutoTraceIdGeneration)
        assertEquals("sentry.java.android.flutter", options.sdkVersion!!.name)
        assertEquals("sentry.native.android.flutter", options.nativeSdkName)
    }

    // Each privacy option is set, not left to the sentry-java default, so an upgrade that changes a default changes
    // nothing. Each case starts from options whose value is the unsafe one, as a changed default would leave it.
    @Suppress("DEPRECATION") // sendDefaultPii, which sentry-java 8.61 replaces with dataCollection
    private fun unsafeOptions() = SentryAndroidOptions().apply {
        isSendDefaultPii = true
        dataCollection = DataCollection().apply {
            forceDataCollection()
            userInfo = true
            cookies = KeyValueCollectionBehavior.denyList()
            urlQueryParams = KeyValueCollectionBehavior.denyList()
            httpBodies = HttpBodyType.values().toSet()
            databaseQueryData = true
            filePaths = true
            httpHeaders.request = KeyValueCollectionBehavior.denyList()
            httpHeaders.response = KeyValueCollectionBehavior.denyList()
            graphql.document = true
            graphql.variables = true
        }
        isAttachScreenshot = true
        isAttachViewHierarchy = true
        maxRequestBodySize = SentryOptions.RequestSize.ALWAYS
        sessionReplay.sessionSampleRate = 1.0
        sessionReplay.onErrorSampleRate = 1.0
        sessionReplay.isNetworkCaptureBodies = true
    }

    // dataCollection replaces the deprecated sendDefaultPii. Once it is set, each of its options left unset collects
    // (DataCollectionResolver in sentry-java 8.61.0), so every one is set off, and sendDefaultPii no longer counts.
    @Test
    fun setsDataCollectionToCollectNoPersonalDataWhateverTheDefault() {
        val resolver = configured(unsafeOptions()).dataCollectionResolver

        assertTrue(resolver.isDataCollectionConfigured)
        assertFalse(resolver.isUserInfo)
        assertFalse(resolver.isDatabaseQueryData)
        assertFalse(resolver.isFilePaths)
        assertFalse(resolver.isGraphqlDocument)
        assertFalse(resolver.isGraphqlDocumentWithLegacyBodyGate)
        assertFalse(resolver.isGraphqlDocumentWithLegacyAlways)
        assertFalse(resolver.isGraphqlVariables)
        assertFalse(resolver.isGraphqlVariablesWithLegacyBodyGate)
        assertFalse(resolver.isGraphqlVariablesWithLegacyAlways)
        assertEquals(KeyValueCollectionBehavior.off(), resolver.cookies)
        assertEquals(KeyValueCollectionBehavior.off(), resolver.urlQueryParams)
        assertEquals(KeyValueCollectionBehavior.off(), resolver.httpRequestHeaders)
        assertEquals(KeyValueCollectionBehavior.off(), resolver.httpResponseHeaders)
        assertFalse(resolver.isIncomingRequestBody)
        assertFalse(resolver.isOutgoingRequestBody)
        assertFalse(resolver.isIncomingResponseBody)
        assertFalse(resolver.isOutgoingResponseBody)
        assertFalse(resolver.isOutgoingResponseBodyWithLegacyBodyGate)
    }

    // A sentry-java upgrade that adds a dataCollection option would collect it, since the options here are set; this
    // fails until the new option is set off in NativeSentry and named below.
    @Test
    fun setsEveryDataCollectionOption() {
        val collection = configured().dataCollection
        val values = mapOf(
            "" to collection,
            "httpHeaders." to collection.httpHeaders,
            "graphql." to collection.graphql,
        ).flatMap { (prefix, owner) ->
            owner.javaClass.methods
                .filter { it.name.startsWith("get") && it.parameterCount == 0 && it.declaringClass == owner.javaClass }
                .filter { it.returnType != DataCollection.HttpHeaders::class.java }
                .filter { it.returnType != DataCollection.Graphql::class.java }
                .map { prefix + it.name.removePrefix("get").replaceFirstChar(Char::lowercase) to it.invoke(owner) }
        }.toMap()

        assertEquals(
            setOf(
                "userInfo",
                "cookies",
                "urlQueryParams",
                "httpBodies",
                "databaseQueryData",
                "filePaths",
                "httpHeaders.request",
                "httpHeaders.response",
                "graphql.document",
                "graphql.variables",
            ),
            values.keys,
        )
        assertEquals(emptyList<String>(), values.filterValues { it == null }.keys.toList())
    }

    // The user info option decides whether an event asks Sentry to store the device's IP address ({{auto}}).
    @Test
    fun asksForNoIpAddressWhateverTheDefault() {
        val event = SentryEvent().apply { user = User() }

        MainEventProcessor(configured(unsafeOptions())).process(event, Hint())

        assertNull(event.user!!.ipAddress)
    }

    @Test
    fun setsScreenshotAttachmentOffWhateverTheDefault() {
        assertFalse(configured(unsafeOptions()).isAttachScreenshot)
    }

    @Test
    fun setsViewHierarchyAttachmentOffWhateverTheDefault() {
        assertFalse(configured(unsafeOptions()).isAttachViewHierarchy)
    }

    @Test
    fun setsRequestBodiesOffWhateverTheDefault() {
        assertEquals(SentryOptions.RequestSize.NONE, configured(unsafeOptions()).maxRequestBodySize)
    }

    @Test
    fun setsSessionReplayOffWhateverTheDefault() {
        val replay = configured(unsafeOptions()).sessionReplay

        assertEquals(0.0, replay.sessionSampleRate!!, 0.0)
        assertEquals(0.0, replay.onErrorSampleRate!!, 0.0)
        assertFalse(replay.isNetworkCaptureBodies)
        assertFalse(replay.isSessionReplayEnabled)
        assertFalse(replay.isSessionReplayForErrorsEnabled)
    }

    // Logs stay on for an explicit Sentry.logger call, as sentry_flutter sets them; nothing in the app makes one, and
    // without the Sentry Android Gradle plugin no logcat line becomes a log (sentry_native_scrub_patterns_test.dart).
    @Test
    fun keepsLogsForExplicitCallsOnly() {
        val options = configured()

        assertTrue(options.logs.isEnabled)
        assertNull(options.logs.beforeSend)
    }

    // The store build declares encryption in transit (#218): the native SDK starts before the Flutter engine, so it
    // refuses a DSN that is not https itself, before the Dart check in AppConfig.fromEnvironment could.
    @Test
    fun refusesADsnThatIsNotHttpsWithoutPrintingIt() {
        for (dsn in listOf("http://publickey@example.invalid/1", "publickey@example.invalid/1", "https:///1", "a b")) {
            val error = assertThrows(IllegalStateException::class.java) { NativeSentry.requireHttpsDsn(dsn) }
            assertTrue(error.message, error.message!!.contains("SENTRY_DSN must be an https URL"))
            assertFalse(error.message, error.message!!.contains("publickey"))
        }
    }

    // The rule of AppConfig.isHttpsUrl, so the two sides never disagree on a DSN.
    @Test
    fun acceptsAnHttpsDsnInAnyCaseWithTheHostsDartAccepts() {
        for (dsn in listOf(
            "https://publickey@example.invalid/1",
            "HTTPS://publickey@example.invalid/1",
            "https://publickey@my_sentry.example.invalid/1",
            "https://publickey@sentry.example.invalid:8443/1",
            "https://publickey@[::1]:8443/1",
        )) {
            NativeSentry.requireHttpsDsn(dsn)
        }
    }

    @Test
    fun refusesSurroundingWhitespaceSayingSo() {
        for (dsn in listOf(" https://publickey@example.invalid/1", "https://publickey@example.invalid/1\n")) {
            val error = assertThrows(IllegalStateException::class.java) { NativeSentry.requireHttpsDsn(dsn) }
            assertTrue(error.message, error.message!!.contains("SENTRY_DSN has leading or trailing whitespace"))
            assertFalse(error.message, error.message!!.contains("publickey"))
        }
    }
}
