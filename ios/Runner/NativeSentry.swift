import Foundation
import Sentry

/// Starts sentry-cocoa from the iOS host app, before the Flutter engine, with the scrubbing hooks of
/// `NativeSentryScrubber`, so what the native SDK records itself leaves the device masked. On iOS, as on Android,
/// the Dart side turns `autoInitializeNativeSdk` off (configureNativeSdkStart in
/// lib/infrastructure/analytics/native_sentry_start.dart) and its events leave through this SDK, which answers
/// `isEnabled` on `channelName`.
///
/// It starts only when the build carries a DSN: ios/native_sentry_defines.sh puts SENTRY_DSN into the built
/// Info.plist only for a lib/main/main_prod.dart build, the only one in which the Dart side starts Sentry, as
/// android/app/build.gradle.kts does for the Android host.
///
/// sentry_flutter passes no Dart option to this SDK then, so `configure` repeats what it would set (SentryFlutter
/// .update and initNativeSdk of sentry_flutter 10.1.0, darwin/sentry_flutter/Sources/sentry_flutter) where the
/// sentry-cocoa 9.30.2 default differs from the Dart one: logs, metrics and the origin tag of a native event. The
/// other options it sets keep the sentry-cocoa default, which equals the Dart default (session tracking, app hangs,
/// watchdog terminations, stack traces, breadcrumbs, cache and attachment limits, client reports). The privacy
/// options are set explicitly on both sides (`setPrivacyOptions`).
/// Not mirrored: the Dart SDK's integrations and packages, which sentry_flutter adds to the native SDK version
/// through private API, and Session Replay, whose recorder callbacks are created in Dart and which stays off.
/// A native option set on the Dart side (configureSentryOptions in lib/app/bootstrap/sentry_start.dart) must be set
/// here too, or it does nothing on iOS.
enum NativeSentry {
  /// The channel on which `AppDelegate` answers whether this SDK started; nativeSdkReady
  /// (lib/infrastructure/analytics/native_sentry_start.dart) asks before the Dart side starts its own.
  static let channelName = "org.libredb.mobile/native_sentry"

  /// The Info.plist keys ios/native_sentry_defines.sh writes from the dart-defines of a prod build.
  static let dsnKey = "SENTRY_DSN"
  static let environmentKey = "SENTRY_ENVIRONMENT"
  static let distKey = "SENTRY_DIST"

  /// Verbatim the pattern of AppConfig.isHttpsUrl (lib/infrastructure/config/environment.dart), so the two agree.
  private static let httpsUrl = try? NSRegularExpression(
    pattern:
      #"^[Hh][Tt][Tt][Pp][Ss]://([^/?#@\x00-\x20\x7F]*@)?(\[[0-9A-Fa-f:.]+\]|[^/?#@:\[\]\x00-\x20\x7F]+)(:[0-9]*)?([/?#]|$)"#
  )

  /// Starts the native SDK when `bundle` carries a DSN, and does nothing when it does not.
  ///
  /// A DSN that is not an https URL stops the app at start instead of sending crash reports over plain http
  /// (docs/security.md, "Encryption in transit"), as the Android host does. The message names only the key: the DSN
  /// carries the project's key. The Dart side checks the same define in AppConfig.fromEnvironment, after this.
  static func start(bundle: Bundle = .main) {
    guard let dsn = string(dsnKey, in: bundle), !dsn.isEmpty else { return }
    precondition(
      isHttpsDsn(dsn),
      "\(dsnKey) must be an https URL without surrounding whitespace in a prod build (docs/security.md, "
        + "\"Encryption in transit\")")
    let version = string("CFBundleShortVersionString", in: bundle) ?? ""
    let build = string("CFBundleVersion", in: bundle) ?? ""
    SentrySDK.start { options in
      configure(
        options,
        dsn: dsn,
        // The release AppBootstrap sets on the Dart side, from the same bundle keys.
        release: "\(version)+\(build)",
        dist: string(distKey, in: bundle) ?? build,
        environment: string(environmentKey, in: bundle) ?? defaultEnvironment)
    }
  }

  /// Whether `dsn` is an https URL, with the rule of AppConfig.isHttpsUrl, and without the surrounding whitespace
  /// the Dart side refuses as well.
  static func isHttpsDsn(_ dsn: String) -> Bool {
    guard let httpsUrl, dsn == dsn.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
    return httpsUrl.firstMatch(in: dsn, range: NSRange(location: 0, length: (dsn as NSString).length)) != nil
  }

  /// Sets `options` as sentry_flutter would, and installs the scrubbing hooks of `scrubber`.
  static func configure(
    _ options: Options,
    dsn: String,
    release: String,
    dist: String,
    environment: String,
    scrubber: NativeSentryScrubber = .shared
  ) {
    options.dsn = dsn
    options.releaseName = release
    options.dist = dist
    options.environment = environment
    // For an explicit SentrySDK.logger call only, which the app makes nowhere, as sentry_flutter sets them.
    options.enableLogs = true
    options.enableMetrics = true
    setPrivacyOptions(options)
    options.beforeSend = scrubbingBeforeSend(scrubber: scrubber)
    options.beforeBreadcrumb = { breadcrumb in scrubber.beforeBreadcrumb(breadcrumb) }
  }

  /// Scrubs each event and tags where it came from, or answers nil for an event that could not be scrubbed, which is
  /// then neither tagged nor sent.
  ///
  /// sentry_flutter tags a native event in the `beforeSend` its initNativeSdk installs (SentryFlutterPlugin.swift),
  /// which it never runs when the host starts the SDK. On iOS a Dart event reaches the native SDK as a ready
  /// envelope, which no `beforeSend` sees, so every event here is a native one.
  static func scrubbingBeforeSend(
    scrubber: NativeSentryScrubber = .shared,
    logError: @escaping (String, String) -> Void = NativeSentryScrubber.logToConsole
  ) -> (Event) -> Event? {
    { event in
      guard let scrubbed = scrubber.beforeSend(event, logError: logError) else { return nil }
      var tags = scrubbed.tags ?? [:]
      tags["event.origin"] = "ios"
      tags["event.environment"] = "native"
      scrubbed.tags = tags
      return scrubbed
    }
  }

  /// Sets each privacy option even where it equals the sentry-cocoa default, as configureSentryOptions does on the
  /// Dart side, so an upgrade that changes a default cannot start sending more: no personal data by default, no
  /// screenshot and no view hierarchy attached to an event, and Session Replay off, with everything masked and no
  /// network body in a replay.
  private static func setPrivacyOptions(_ options: Options) {
    options.sendDefaultPii = false
    options.attachScreenshot = false
    options.attachViewHierarchy = false
    options.sessionReplay.sessionSampleRate = 0
    options.sessionReplay.onErrorSampleRate = 0
    options.sessionReplay.maskAllText = true
    options.sessionReplay.maskAllImages = true
    options.sessionReplay.networkCaptureBodies = false
  }

  /// The environment the Dart SDK picks by build mode when SENTRY_ENVIRONMENT is not defined. A debug or profile
  /// build carries no DSN, so this is "production" in every build that starts this SDK, but it is spelled out the
  /// way the Dart side spells it.
  private static var defaultEnvironment: String {
    #if DEBUG
      return "debug"
    #else
      return "production"
    #endif
  }

  private static func string(_ key: String, in bundle: Bundle) -> String? {
    guard let value = bundle.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else { return nil }
    return value
  }
}
