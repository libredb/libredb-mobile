import java.io.File
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter passes the --dart-define values as the `dart-defines` Gradle property: each entry is base64 encoded and the
// entries are separated by commas (encodeDartDefines in packages/flutter_tools/lib/src/build_info.dart).
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        .orEmpty()
        .split(",")
        .filter { it.isNotEmpty() }
        .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        .associate { it.substringBefore("=") to it.substringAfter("=", "") }

// The host app starts sentry-android itself (NativeSentry.kt), and only when the Dart side starts Sentry: in the prod
// environment, which only lib/main/main_prod.dart selects, with a SENTRY_DSN (AppConfig.sentryDsn). On Android every
// Dart event leaves the device through the native SDK, so the two gates must agree; renaming lib/main/main_prod.dart
// means changing it here too (test/architecture/sentry_native_scrub_patterns_test.dart checks it, and nativeSdkReady
// fails at start when the gates disagree).
val isProdTarget = File(project.findProperty("target") as String? ?: "").name == "main_prod.dart"

// The upload key that signs a release build (docs/release.md): each value comes from its environment variable, else
// from the git-ignored android/key.properties, and a relative store file resolves against android/. With all four
// values the release build signs with the upload key. With none it signs with the debug key, so a pull request build
// needs no secret, unless -PrequireReleaseSigning=true asks for the upload key. A partial set always fails the build.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}

fun signingValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: keyProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val uploadSigning: Map<String, String?> = mapOf(
    "ANDROID_UPLOAD_STORE_FILE" to signingValue("ANDROID_UPLOAD_STORE_FILE", "storeFile"),
    "ANDROID_UPLOAD_STORE_PASSWORD" to signingValue("ANDROID_UPLOAD_STORE_PASSWORD", "storePassword"),
    "ANDROID_UPLOAD_KEY_ALIAS" to signingValue("ANDROID_UPLOAD_KEY_ALIAS", "keyAlias"),
    "ANDROID_UPLOAD_KEY_PASSWORD" to signingValue("ANDROID_UPLOAD_KEY_PASSWORD", "keyPassword"),
)
val missingUploadSigning = uploadSigning.filterValues { it == null }.keys
val hasUploadSigning = missingUploadSigning.isEmpty()
val requireReleaseSigning = (project.findProperty("requireReleaseSigning") as String?) == "true"

if (!hasUploadSigning && (requireReleaseSigning || missingUploadSigning.size < uploadSigning.size)) {
    throw GradleException(
        "Release signing needs the upload key, but these values are missing: ${missingUploadSigning.joinToString()}. " +
            "Set each as an environment variable, or set storeFile, storePassword, keyAlias and keyPassword in " +
            "android/key.properties (docs/release.md).",
    )
}
// A signed build is a store build, so it refuses the defines meant for checks only, as the release workflow does.
if (requireReleaseSigning) {
    val checkOnlyDefines = rootProject.file("../tool/release/check_only_defines.txt").readLines()
        .map { it.substringBefore("#").trim() }
        .filter { it.isNotEmpty() }
    val carried = checkOnlyDefines.filter { it in dartDefines }
    if (carried.isNotEmpty()) {
        throw GradleException(
            "A signed release build must not carry a define meant for checks only: ${carried.joinToString()} " +
                "(tool/release/check_only_defines.txt).",
        )
    }
}
val uploadStoreFile = uploadSigning["ANDROID_UPLOAD_STORE_FILE"]?.let { rootProject.file(it) }
if (uploadStoreFile != null && !uploadStoreFile.isFile) {
    throw GradleException("The upload keystore that ANDROID_UPLOAD_STORE_FILE or storeFile names does not exist.")
}

// The id release.yml gives the R8 mapping it uploads to Sentry (docs/release.md, "Crash symbols"). The native SDK reports
// it with each event, so Sentry can match the mapping; a build without -PsentryProguardUuid reports none.
val sentryProguardUuid = (project.findProperty("sentryProguardUuid") as String?).orEmpty()
if (sentryProguardUuid.isNotEmpty() &&
    !Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}").matches(sentryProguardUuid)
) {
    throw GradleException("-PsentryProguardUuid must be a lowercase UUID, such as the output of uuidgen.")
}

fun buildConfigString(value: String) = "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

android {
    namespace = "org.libredb.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.libredb.mobile"
        // sentry_flutter 10 requires Android API 26 or higher.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The oidc_android redirect activity listens on this scheme; it must match OidcSettings.defaultRedirectScheme.
        manifestPlaceholders["oidcRedirectScheme"] = "org.libredb.mobile"
        // The DSN is the public key that --dart-define already compiles into the Dart snapshot.
        val nativeSentryDsn = if (isProdTarget) dartDefines["SENTRY_DSN"].orEmpty() else ""
        buildConfigField("String", "SENTRY_DSN", buildConfigString(nativeSentryDsn))
        buildConfigField("String", "SENTRY_ENVIRONMENT", buildConfigString(dartDefines["SENTRY_ENVIRONMENT"].orEmpty()))
        buildConfigField("String", "SENTRY_DIST", buildConfigString(dartDefines["SENTRY_DIST"].orEmpty()))
        // Only a prod build starts the native SDK.
        val nativeProguardUuid = if (isProdTarget) sentryProguardUuid else ""
        buildConfigField("String", "SENTRY_PROGUARD_UUID", buildConfigString(nativeProguardUuid))
        // The native crash of the Sentry device check (SentryDeviceCheck.kt, docs/crash-reporting.md), only in a build
        // that also starts the native SDK.
        val sentryDeviceCheck = isProdTarget && dartDefines["SENTRY_DEVICE_CHECK"] == "true"
        buildConfigField("boolean", "SENTRY_DEVICE_CHECK", sentryDeviceCheck.toString())
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (hasUploadSigning) {
            create("release") {
                storeFile = uploadStoreFile
                storePassword = uploadSigning["ANDROID_UPLOAD_STORE_PASSWORD"]
                keyAlias = uploadSigning["ANDROID_UPLOAD_KEY_ALIAS"]
                keyPassword = uploadSigning["ANDROID_UPLOAD_KEY_PASSWORD"]
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadSigning) "release" else "debug")
        }
    }
}

// Says in the build log which key signs a release build: the upload keystore's file name, never a value of the key.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        val key = uploadStoreFile?.let { "the upload key in ${it.name}" } ?: "the debug key"
        logger.quiet("Release build signed with $key.")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// NativeSentryScrubberTest reads the fixtures the Dart tests share, so a changed fixture runs the JVM tests again.
tasks.withType<Test>().configureEach {
    inputs.dir(rootProject.file("../test/fixtures")).withPropertyName("sharedScrubFixtures")
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    // Reads test/fixtures/native_scrub_cases.json, which the Dart scrubber test runs too.
    testImplementation("com.google.code.gson:gson:2.13.2")
}
