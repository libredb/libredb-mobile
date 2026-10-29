import Sentry
import XCTest

@testable import Runner

/// The iOS half of the native scrub policy, over the cases
/// `android/app/src/test/kotlin/org/libredb/mobile/NativeSentryScrubberTest.kt` runs on the JVM, so what
/// sentry-cocoa records itself leaves this device masked exactly as sentry-android's own records leave an Android
/// one. `test/fixtures/native_scrub_cases.json` and `native_scrub_map_cases.json` are the cases the Dart, the JVM
/// and these tests all run: they are resources of this test bundle, read from the repository.
final class NativeSentryScrubberTests: XCTestCase {
  private let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhYmMifQ.signaturepart"
  // The fake header values of the shared fixtures, joined at run time, so this file holds no string a secret
  // scanner reads as a credential.
  private let opaqueToken = ["at", "opaque", "0a1b2c3d"].joined(separator: "-")
  private let apiKey = ["k", "0a1b2c3d4e"].joined(separator: "-")
  private var logged: [String] = []
  private var loggedKinds: [String] = []
  private lazy var logError: (String, String) -> Void = { [unowned self] message, kind in
    self.logged.append(message)
    self.loggedKinds.append(kind)
  }

  private var scrubber: NativeSentryScrubber { NativeSentryScrubber.shared }

  /// A scrubber whose JWT pattern does not compile, which masks nothing and drops what it is given.
  private var broken: NativeSentryScrubber { NativeSentryScrubber(jwtPattern: "eyJ[A-Za-z") }

  override func setUp() {
    super.setUp()
    logged = []
    loggedKinds = []
  }

  func testMasksAnEmailAndAJwtInTheMessageTheExceptionValueAndBreadcrumbData() throws {
    let crumb = Breadcrumb()
    crumb.message = "user jane.doe@example.com"
    crumb.setData(value: "Bearer \(jwt)", key: "auth")
    let event = Event()
    let message = SentryMessage(formatted: "user jane.doe@example.com token \(jwt)")
    message.message = "user %s token %s"
    message.params = ["jane.doe@example.com", jwt]
    event.message = message
    event.exceptions = [Exception(value: "jane.doe@example.com \(jwt)", type: "StateError")]
    event.breadcrumbs = [crumb]

    let result = try XCTUnwrap(scrubber.beforeSend(event, logError: logError))

    XCTAssertEqual(result.message?.formatted, "user [REDACTED_EMAIL] token [REDACTED_JWT]")
    XCTAssertEqual(result.message?.message, "user %s token %s")
    XCTAssertEqual(result.message?.params, ["[REDACTED_EMAIL]", "[REDACTED_JWT]"])
    XCTAssertEqual(result.exceptions?.first?.value, "[REDACTED_EMAIL] [REDACTED_JWT]")
    XCTAssertEqual(crumb.message, "user [REDACTED_EMAIL]")
    XCTAssertEqual(crumb.data?["auth"] as? String, "Bearer [REDACTED_JWT]")
  }

  func testMasksAnEmailAndAJwtInTheMessageAndDataOfABreadcrumb() throws {
    let crumb = Breadcrumb(level: .info, category: "http")
    crumb.message = "GET /admin/users/jane.doe@example.com"
    crumb.setData(value: "https://api.example.test/users/jane.doe@example.com?access_token=\(jwt)", key: "url")
    crumb.setData(value: 503, key: "status_code")
    crumb.setData(
      value: ["login": "admin", "newPassword": "Adm1nSet!Pw", "emails": ["j@example.org"]] as [String: Any],
      key: "form")
    crumb.setData(value: "493817", key: "otp")

    let result = scrubber.beforeBreadcrumb(crumb, logError: logError)

    XCTAssertTrue(result === crumb)
    XCTAssertEqual(crumb.message, "GET /admin/users/[REDACTED_EMAIL]")
    XCTAssertEqual(
      crumb.data?["url"] as? String, "https://api.example.test/users/[REDACTED_EMAIL]?access_token=[REDACTED_JWT]")
    XCTAssertEqual(crumb.data?["status_code"] as? Int, 503)
    XCTAssertEqual(
      crumb.data?["form"] as? NSDictionary,
      ["login": "admin", "newPassword": "[REDACTED]", "emails": ["[REDACTED_EMAIL]"]] as NSDictionary)
    XCTAssertEqual(crumb.data?["otp"] as? String, "[REDACTED]")
  }

  func testKeepsTheNavigatorEventOfANavigationBreadcrumb() {
    let crumb = Breadcrumb(level: .info, category: "navigation")
    crumb.setData(value: "didPush", key: "state")
    crumb.setData(value: "login-otp-verify", key: "to")

    _ = scrubber.beforeBreadcrumb(crumb, logError: logError)

    XCTAssertEqual(crumb.data as? NSDictionary, ["state": "didPush", "to": "login-otp-verify"] as NSDictionary)
  }

  func testMasksStateInABreadcrumbThatIsNotANavigationOne() {
    let event = Breadcrumb(level: .info, category: "event")
    event.setData(value: "didPop", key: "state")
    let callback = Breadcrumb(level: .info, category: "navigation")
    callback.setData(value: "st4te999", key: "state")

    _ = scrubber.beforeBreadcrumb(event, logError: logError)
    _ = scrubber.beforeBreadcrumb(callback, logError: logError)

    XCTAssertEqual(event.data?["state"] as? String, "[REDACTED]")
    XCTAssertEqual(callback.data?["state"] as? String, "[REDACTED]")
  }

  func testKeepsTheStateOfAnAppLifecycleBreadcrumb() {
    let states = ["foreground", "active", "inactive", "background"]

    let kept = states.map { state -> String? in
      let crumb = Breadcrumb(level: .info, category: "app.lifecycle")
      crumb.type = "navigation"
      crumb.setData(value: state, key: "state")
      _ = scrubber.beforeBreadcrumb(crumb, logError: logError)
      return crumb.data?["state"] as? String
    }

    XCTAssertEqual(kept, states)
  }

  func testMasksAStateThatIsNoLifecycleStateInALifecycleBreadcrumb() {
    // sentry-cocoa 9.30.2 puts no `state` into a ui.lifecycle breadcrumb (SentryBreadcrumbTracker), so one that
    // carries it is no lifecycle state of this platform and is masked.
    let screen = Breadcrumb(level: .info, category: "ui.lifecycle")
    screen.setData(value: "foreground", key: "state")
    let app = Breadcrumb(level: .info, category: "app.lifecycle")
    app.setData(value: "st4te999", key: "state")

    _ = scrubber.beforeBreadcrumb(screen, logError: logError)
    _ = scrubber.beforeBreadcrumb(app, logError: logError)

    XCTAssertEqual(screen.data?["state"] as? String, "[REDACTED]")
    XCTAssertEqual(app.data?["state"] as? String, "[REDACTED]")
  }

  // A Dart breadcrumb reaches the native hook already masked, when Sentry syncs it to the native scope.
  func testMasksTheSameTextTwiceToTheSameResult() {
    let once = scrubber.maskText("{\"password\":\"x\"} jane.doe@example.com \(jwt) code=4f2a9c")

    XCTAssertEqual(once, "{\"password\":\"[REDACTED]\"} [REDACTED_EMAIL] [REDACTED_JWT] code=[REDACTED]")
    XCTAssertEqual(scrubber.maskText(once), once)
  }

  func testMasksEveryCaseOfTheFixtureSharedWithTheDartScrubber() throws {
    let cases = try fixture("native_scrub_cases", as: [FixtureCase].self)

    XCTAssertFalse(cases.isEmpty)
    for test in cases {
      XCTAssertEqual(scrubber.maskText(test.input), test.expected, "input: \(test.input)")
    }
  }

  func testMasksTheRequestLikeTheDartScrubber() throws {
    let event = Event()
    let request = SentryRequest()
    request.url = "https://api.example.test/users/jane.doe@example.com"
    request.queryString = "token=\(jwt)"
    request.fragment = "/login-otp-verify/jane.doe@example.com"
    request.cookies = "sid=abc"
    request.headers = [
      "Authorization": "Bearer \(jwt)",
      "Cookie": "sid=abc",
      "X-Auth-Token": opaqueToken,
      "X-Debug-Context": "session \(jwt)",
      "Accept": "application/json",
    ]
    event.request = request
    event.transaction = "/login-otp-verify/jane.doe@example.com"

    let scrubbed = try XCTUnwrap(scrubber.beforeSend(event, logError: logError).flatMap { $0.request })

    XCTAssertEqual(scrubbed.url, "https://api.example.test/users/[REDACTED_EMAIL]")
    XCTAssertEqual(scrubbed.queryString, "token=[REDACTED_JWT]")
    XCTAssertEqual(scrubbed.fragment, "/login-otp-verify/[REDACTED_EMAIL]")
    XCTAssertNil(scrubbed.cookies)
    XCTAssertEqual(
      scrubbed.headers,
      [
        "X-Auth-Token": "[REDACTED]",
        "X-Debug-Context": "session [REDACTED_JWT]",
        "Accept": "application/json",
      ])
    XCTAssertEqual(event.transaction, "/login-otp-verify/[REDACTED_EMAIL]")
  }

  func testMasksTheExtraAndTheTags() {
    let event = Event()
    event.extra = [
      "user": "jane.doe@example.com",
      "session": ["refreshToken": "rt-9f8e7d6c", "count": 3] as [String: Any],
    ]
    event.tags = ["login": "jane.doe@example.com", "event.origin": "ios"]

    _ = scrubber.beforeSend(event, logError: logError)

    XCTAssertEqual(event.extra?["user"] as? String, "[REDACTED_EMAIL]")
    XCTAssertEqual(
      event.extra?["session"] as? NSDictionary, ["refreshToken": "[REDACTED]", "count": 3] as NSDictionary)
    XCTAssertEqual(event.tags?["login"], "[REDACTED_EMAIL]")
    XCTAssertEqual(event.tags?["event.origin"], "ios")
  }

  func testMasksTheValueOfATagNamedLikeACredential() {
    let event = Event()
    event.tags = ["otp": "493817", "event.origin": "ios"]

    _ = scrubber.beforeSend(event, logError: logError)

    XCTAssertEqual(event.tags?["otp"], "[REDACTED]")
    XCTAssertEqual(event.tags?["event.origin"], "ios")
  }

  func testMasksTheWholeValueOfAnAuthorizationOrApiKeyHeader() throws {
    let event = Event()
    let request = SentryRequest()
    request.headers = [
      "Proxy-Authorization": "Basic dXNlcjpwYXNz",
      "X-Api-Key": apiKey,
      "X-Keyboard-Layout": "tr-q",
    ]
    event.request = request

    let headers = try XCTUnwrap(scrubber.beforeSend(event, logError: logError).flatMap { $0.request?.headers })

    XCTAssertEqual(
      headers,
      [
        "Proxy-Authorization": "[REDACTED]",
        "X-Api-Key": "[REDACTED]",
        "X-Keyboard-Layout": "tr-q",
      ])
  }

  // Scope sync copies the Dart user to the native scope, so a setUserId call with an email would send it in every
  // native crash.
  func testMasksTheUserLikeTheDartScrubber() throws {
    let event = Event()
    let user = User()
    user.userId = "jane.doe@example.com"
    user.username = "jane \(jwt)"
    user.email = "jane.doe@example.com"
    user.ipAddress = "203.0.113.7"
    user.name = "Jane token=at-0a1b"
    user.data = ["refreshToken": "rt-9f8e7d6c", "plan": "pro", "contact": "j@example.org"]
    event.user = user

    let scrubbed = try XCTUnwrap(scrubber.beforeSend(event, logError: logError).flatMap { $0.user })

    XCTAssertEqual(scrubbed.userId, "[REDACTED_EMAIL]")
    XCTAssertEqual(scrubbed.username, "jane [REDACTED_JWT]")
    XCTAssertEqual(scrubbed.email, "[REDACTED_EMAIL]")
    XCTAssertEqual(scrubbed.ipAddress, "203.0.113.7")
    XCTAssertEqual(scrubbed.name, "Jane token=[REDACTED]")
    XCTAssertEqual(
      scrubbed.data as? NSDictionary,
      ["refreshToken": "[REDACTED]", "plan": "pro", "contact": "[REDACTED_EMAIL]"] as NSDictionary)
  }

  func testMasksEveryMapCaseOfTheFixtureSharedWithTheDartScrubber() throws {
    let cases = try fixture("native_scrub_map_cases", as: [MapFixtureCase].self)

    XCTAssertFalse(cases.isEmpty)
    for test in cases {
      let event = Event()
      switch test.field {
      case "headers":
        let request = SentryRequest()
        request.headers = test.input
        event.request = request
      case "tags":
        event.tags = test.input
      default:
        XCTFail("unknown field \(test.field)")
        continue
      }

      let result = try XCTUnwrap(scrubber.beforeSend(event, logError: logError))

      let masked = test.field == "headers" ? result.request?.headers : result.tags
      XCTAssertEqual(masked, test.expected, test.field)
    }
  }

  // Fail closed: a pattern that does not compile masks nothing, so nothing it was given may be sent.
  func testDropsTheEventAndLogsWhenAPatternDoesNotCompile() {
    let scrubber = broken
    let event = Event()
    event.extra = ["user": "jane.doe@example.com"]

    XCTAssertNil(scrubber.beforeSend(event, logError: logError))
    XCTAssertEqual(logged, ["Dropped a native event: scrubbing it failed"])
    XCTAssertEqual(loggedKinds, ["a scrub pattern did not compile"])
  }

  func testDropsTheBreadcrumbAndLogsWhenAPatternDoesNotCompile() {
    let scrubber = broken
    let crumb = Breadcrumb()
    crumb.message = "jane.doe@example.com"

    XCTAssertNil(scrubber.beforeBreadcrumb(crumb, logError: logError))
    XCTAssertEqual(logged, ["Dropped a native breadcrumb: scrubbing it failed"])
    XCTAssertEqual(loggedKinds, ["a scrub pattern did not compile"])
  }

  // Masking must never answer the text it was given when it could not mask it.
  func testMasksTextWholeWhenAPatternDoesNotCompile() {
    XCTAssertEqual(broken.maskText("jane.doe@example.com \(jwt)"), "[REDACTED]")
  }

  // sentry_flutter tags the origin of a native event in the beforeSend it installs in initNativeSdk, which it never
  // runs when the host starts the SDK; the host tags it and keeps the scrubbed event.
  func testTagsTheOriginOfTheScrubbedNativeEvent() throws {
    let callback = NativeSentry.scrubbingBeforeSend(scrubber: scrubber, logError: logError)
    let event = Event()
    event.exceptions = [Exception(value: "jane.doe@example.com", type: "NSError")]

    let result = try XCTUnwrap(callback(event))

    XCTAssertEqual(result.exceptions?.first?.value, "[REDACTED_EMAIL]")
    XCTAssertEqual(result.tags?["event.origin"], "ios")
    XCTAssertEqual(result.tags?["event.environment"], "native")
  }

  func testNeitherTagsNorSendsAnEventWhoseScrubbingFailed() {
    let callback = NativeSentry.scrubbingBeforeSend(scrubber: broken, logError: logError)
    let event = Event()
    event.exceptions = [Exception(value: "jane.doe@example.com", type: "NSError")]

    XCTAssertNil(callback(event))
    XCTAssertNil(event.tags?["event.origin"])
  }

  func testStartsOnlyWithAnHttpsDsn() {
    XCTAssertTrue(NativeSentry.isHttpsDsn("https://key@o1.ingest.sentry.io/2"))
    XCTAssertFalse(NativeSentry.isHttpsDsn("http://key@o1.ingest.sentry.io/2"))
    XCTAssertFalse(NativeSentry.isHttpsDsn(" https://key@o1.ingest.sentry.io/2"))
    XCTAssertFalse(NativeSentry.isHttpsDsn("https://key@o1.ingest.sentry.io/2 "))
    XCTAssertFalse(NativeSentry.isHttpsDsn(""))
  }

  // Each privacy option is set even where it equals today's sentry-cocoa default, as the Dart side sets it
  // (configureSentryOptions in lib/app/bootstrap/sentry_start.dart): what the Dart side no longer passes to this SDK
  // has to be set here, or an upgrade that changes a default starts sending more.
  func testConfiguresThePrivacyOptionsAndTheScrubbingHooks() {
    let options = Options()

    NativeSentry.configure(
      options, dsn: "https://key@o1.ingest.sentry.io/2", release: "1.0.0+1", dist: "1", environment: "production",
      scrubber: scrubber)

    XCTAssertEqual(options.dsn, "https://key@o1.ingest.sentry.io/2")
    XCTAssertEqual(options.releaseName, "1.0.0+1")
    XCTAssertEqual(options.dist, "1")
    XCTAssertEqual(options.environment, "production")
    XCTAssertFalse(options.sendDefaultPii)
    XCTAssertFalse(options.attachScreenshot)
    XCTAssertFalse(options.attachViewHierarchy)
    XCTAssertEqual(options.sessionReplay.sessionSampleRate, 0)
    XCTAssertEqual(options.sessionReplay.onErrorSampleRate, 0)
    XCTAssertFalse(options.sessionReplay.networkCaptureBodies)
    XCTAssertTrue(options.sessionReplay.maskAllText)
    XCTAssertTrue(options.sessionReplay.maskAllImages)
    XCTAssertNotNil(options.beforeSend)
    XCTAssertNotNil(options.beforeBreadcrumb)
  }

  func testTheHooksTheOptionsCarryScrubAnEventAndABreadcrumb() throws {
    let options = Options()
    NativeSentry.configure(
      options, dsn: "https://key@o1.ingest.sentry.io/2", release: "1.0.0+1", dist: "1", environment: "production",
      scrubber: scrubber)
    let event = Event()
    event.exceptions = [Exception(value: "jane.doe@example.com", type: "NSError")]
    let crumb = Breadcrumb()
    crumb.message = "user jane.doe@example.com"

    let sent = try XCTUnwrap(options.beforeSend?(event))
    let kept = try XCTUnwrap(options.beforeBreadcrumb?(crumb))

    XCTAssertEqual(sent.exceptions?.first?.value, "[REDACTED_EMAIL]")
    XCTAssertEqual(kept.message, "user [REDACTED_EMAIL]")
  }

  private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let url = try XCTUnwrap(
      Bundle(for: NativeSentryScrubberTests.self).url(forResource: name, withExtension: "json"),
      "\(name).json must be a resource of RunnerTests")
    return try JSONDecoder().decode(type, from: Data(contentsOf: url))
  }

  private struct FixtureCase: Decodable {
    let input: String
    let expected: String
  }

  private struct MapFixtureCase: Decodable {
    let field: String
    let input: [String: String]
    let expected: [String: String]
  }
}
