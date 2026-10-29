import Foundation
import Sentry
import os

/// Masks what sentry-cocoa records and sends itself: its own breadcrumbs (app lifecycle, view controller lifecycle,
/// touches, network changes, http requests), NSException and NSError events, app hangs, watchdog terminations and
/// crash reports, none of which pass through the Dart hooks. `NativeSentry` installs `beforeSend` and
/// `beforeBreadcrumb` as the hooks of the native SDK.
///
/// A port of maskSecrets and maskEmails (lib/core/security/sensitive_data_scrubber.dart) and of sentryBeforeSend and
/// sentryBeforeBreadcrumb (lib/infrastructure/analytics/sentry_scrub.dart), with the patterns of
/// `NativeScrubPatterns`, and the Swift twin of
/// android/app/src/main/kotlin/org/libredb/mobile/NativeSentryScrubber.kt.
/// test/fixtures/native_scrub_cases.json holds the cases that all three copies must mask alike.
///
/// Masking is idempotent: a Dart breadcrumb reaches `beforeBreadcrumb` already masked when Sentry syncs it to the
/// native scope. It also fails closed: a scrubber whose patterns did not compile masks every text whole and drops
/// every event and breadcrumb it is given, logging that it did, without their content; it never sends one unmasked.
final class NativeSentryScrubber {
  /// The scrubber the hooks of the running SDK use.
  static let shared = NativeSentryScrubber()

  /// What `logError` is given in place of the message of a failure, which could hold the value it failed on.
  static let unusableKind = "a scrub pattern did not compile"

  private static let sensitiveHeaderNames = set(NativeScrubPatterns.sensitiveHeaderNames)
  private static let sensitiveHeaderNameSubstrings = set(NativeScrubPatterns.sensitiveHeaderNameSubstrings)
  private static let sensitiveBodyKeySubstrings = set(NativeScrubPatterns.sensitiveBodyKeySubstrings)
  private static let sensitiveExactKeys = set(NativeScrubPatterns.sensitiveExactKeys)
  private static let navigationTypes = set(NativeScrubPatterns.navigationTypes)
  private static let credentialNames = sensitiveBodyKeySubstrings.union(sensitiveExactKeys)

  /// The states sentry-cocoa 9.30.2 records under the key `state` in its lifecycle breadcrumbs, by category:
  /// SentryBreadcrumbTracker writes them under `app.lifecycle` on the UIApplication notifications. The key also
  /// carries the OIDC state, so only these values are kept, and only in this category; a `ui.lifecycle` breadcrumb,
  /// which carries the screen and no state of its own, keeps none. Native only: the Dart hook still masks them in
  /// the copies that the native contexts merge into a Dart event.
  private static let lifecycleStates = ["app.lifecycle": Set(["foreground", "active", "inactive", "background"])]

  private let jwt: NSRegularExpression?
  private let email: NSRegularExpression?
  private let jsonMember: NSRegularExpression?
  private let namedValue: NSRegularExpression?
  private let bearer: NSRegularExpression?

  /// Whether every pattern compiled. When it is false the scrubber masks nothing and keeps nothing.
  let isUsable: Bool

  init(
    jwtPattern: String = NativeScrubPatterns.jwtPattern,
    emailPattern: String = NativeScrubPatterns.emailPattern,
    jsonMemberPattern: String = NativeScrubPatterns.jsonMemberPattern,
    namedValuePattern: String = NativeScrubPatterns.namedValuePattern,
    bearerPattern: String = NativeScrubPatterns.bearerPattern
  ) {
    jwt = try? NSRegularExpression(pattern: jwtPattern)
    email = try? NSRegularExpression(pattern: emailPattern)
    jsonMember = try? NSRegularExpression(pattern: jsonMemberPattern)
    namedValue = try? NSRegularExpression(pattern: namedValuePattern)
    bearer = try? NSRegularExpression(pattern: bearerPattern)
    isUsable = jwt != nil && email != nil && jsonMember != nil && namedValue != nil && bearer != nil
  }

  /// The `beforeSend` hook of the native SDK: `event` masked in place, or nil when it could not be masked.
  /// `logError` gets the line and the kind of the failure, never a text of the event.
  func beforeSend(_ event: Event, logError: (String, String) -> Void = NativeSentryScrubber.logToConsole) -> Event? {
    guard isUsable else {
      logError("Dropped a native event: scrubbing it failed", Self.unusableKind)
      return nil
    }
    scrub(event)
    return event
  }

  /// The `beforeBreadcrumb` hook of the native SDK: `breadcrumb` masked in place, or nil when it could not be masked.
  func beforeBreadcrumb(
    _ breadcrumb: Breadcrumb, logError: (String, String) -> Void = NativeSentryScrubber.logToConsole
  ) -> Breadcrumb? {
    guard isUsable else {
      logError("Dropped a native breadcrumb: scrubbing it failed", Self.unusableKind)
      return nil
    }
    scrub(breadcrumb)
    return breadcrumb
  }

  /// Masks emails, JWTs and the other secrets `maskSecrets` finds in `value`.
  func maskText(_ value: String) -> String { maskEmails(maskSecrets(value)) }

  /// The port of maskSecrets.
  func maskSecrets(_ input: String) -> String {
    guard let jwt, let bearer, let jsonMember, let namedValue else { return NativeScrubPatterns.secretMask }
    var text = input.contains("eyJ") ? replace(jwt, in: input) { _ in NativeScrubPatterns.jwtMask } : input
    let lower = text.lowercased()
    if lower.contains("bearer") {
      text = replace(bearer, in: text) { "\($0[1]) \(NativeScrubPatterns.secretMask)" }
    }
    guard Self.credentialNames.contains(where: lower.contains) else { return text }
    if text.contains("\"") {
      text = replace(jsonMember, in: text) { groups in
        let value = groups[3]
        guard Self.isSensitiveKey(groups[1]), !value.hasPrefix("\"[REDACTED") else { return groups[0] }
        let mask = NativeScrubPatterns.secretMask
        return "\"\(groups[1])\"\(groups[2])" + (value.hasPrefix("\"") ? "\"\(mask)\"" : mask)
      }
    }
    if text.contains("=") {
      text = replace(namedValue, in: text) { groups in
        Self.isSensitiveKey(groups[1]) ? "\(groups[1])=\(NativeScrubPatterns.secretMask)" : groups[0]
      }
    }
    return text
  }

  /// The port of maskEmails.
  func maskEmails(_ input: String) -> String {
    guard let email else { return NativeScrubPatterns.secretMask }
    guard input.contains("@") || input.contains("%40") else { return input }
    return replace(email, in: input) { _ in NativeScrubPatterns.emailMask }
  }

  /// `map` with the whole value of every credential key masked, and every other value masked at any depth.
  func maskMap(_ map: [String: Any]) -> [String: Any] {
    var masked: [String: Any] = [:]
    for (key, value) in map {
      if Self.isSensitiveKey(key), !(value is NSNull) {
        masked[key] = NativeScrubPatterns.secretMask
      } else {
        masked[key] = maskValue(value)
      }
    }
    return masked
  }

  /// `map` masked as `maskMap` masks it, with every value as text, for a field that carries only strings.
  func maskTextMap(_ map: [String: String]) -> [String: String] {
    maskMap(map).mapValues { Self.describe($0) }
  }

  /// The hook writes nothing of its own to the console but this: the line and the kind of a failure, never a value.
  static func logToConsole(_ message: String, _ kind: String) {
    os_log(
      "%{public}@ (%{public}@)",
      log: OSLog(subsystem: "org.libredb.mobile", category: "NativeSentryScrubber"), type: .error, message, kind)
  }

  /// Masks every string in `value` at any depth. A value that is neither a number nor a collection is masked as its
  /// text, as the Dart scrubber masks it.
  private func maskValue(_ value: Any?) -> Any {
    switch value {
    case let text as String: return maskText(text)
    case let null as NSNull: return null
    case let number as NSNumber: return number
    case let map as [String: Any]: return maskMap(map)
    case let list as [Any]: return list.map { maskValue($0) }
    case let value?: return maskText(Self.describe(value))
    default: return NSNull()
    }
  }

  private func scrub(_ event: Event) {
    if let message = event.message {
      let masked = SentryMessage(formatted: maskText(message.formatted))
      masked.message = message.message.map { maskText($0) }
      masked.params = message.params?.map { maskText($0) }
      event.message = masked
    }
    event.exceptions?.forEach { exception in
      if let value = exception.value { exception.value = maskText(value) }
    }
    event.breadcrumbs?.forEach { scrub($0) }
    if let extra = event.extra { event.extra = maskMap(extra) }
    if let tags = event.tags { event.tags = maskTextMap(tags) }
    if let user = event.user { scrub(user) }
    if let request = event.request { scrub(request) }
    if let transaction = event.transaction { event.transaction = maskText(transaction) }
  }

  private func scrub(_ breadcrumb: Breadcrumb) {
    if let message = breadcrumb.message { breadcrumb.message = maskText(message) }
    guard let data = breadcrumb.data else { return }
    let state = data["state"]
    for (key, value) in maskMap(data) { breadcrumb.setData(value: value, key: key) }
    if keepsState(breadcrumb.category, state) { breadcrumb.setData(value: state, key: "state") }
  }

  private func keepsState(_ category: String, _ state: Any?) -> Bool {
    guard let state = state as? String else { return false }
    if category == "navigation" { return Self.navigationTypes.contains(state) }
    return Self.lifecycleStates[category]?.contains(state) ?? false
  }

  /// Masks `request` as sentryBeforeSend does: the url parts masked, the cookies dropped, the
  /// `NativeScrubPatterns.sensitiveHeaderNames` dropped, a header whose name names a credential (a body key, or one
  /// of `NativeScrubPatterns.sensitiveHeaderNameSubstrings`) masked whole, and every other header value masked as
  /// text. sentry-cocoa 9.30.2 attaches no request body.
  private func scrub(_ request: SentryRequest) {
    if let url = request.url { request.url = maskText(url) }
    if let queryString = request.queryString { request.queryString = maskText(queryString) }
    if let fragment = request.fragment { request.fragment = maskText(fragment) }
    request.cookies = nil
    guard let headers = request.headers else { return }
    var masked: [String: String] = [:]
    for (name, value) in headers where !Self.sensitiveHeaderNames.contains(name.lowercased()) {
      let credential = Self.isSensitiveKey(name) || Self.namesHeaderCredential(name)
      masked[name] = credential ? NativeScrubPatterns.secretMask : maskText(value)
    }
    request.headers = masked
  }

  /// Masks the text fields of `user` as text, and its data as a breadcrumb's data, as sentryBeforeSend does.
  private func scrub(_ user: User) {
    if let userId = user.userId { user.userId = maskText(userId) }
    if let username = user.username { user.username = maskText(username) }
    if let email = user.email { user.email = maskText(email) }
    if let ipAddress = user.ipAddress { user.ipAddress = maskText(ipAddress) }
    if let name = user.name { user.name = maskText(name) }
    if let data = user.data { user.data = maskMap(data) }
  }

  /// `text` with every match of `pattern` replaced by what `body` answers for its groups, group 0 being the match
  /// itself and a group that did not take part an empty string, as Kotlin's `groupValues` answers it.
  private func replace(_ pattern: NSRegularExpression, in text: String, body: ([String]) -> String) -> String {
    let source = text as NSString
    var result = ""
    var read = 0
    for match in pattern.matches(in: text, range: NSRange(location: 0, length: source.length)) {
      result += source.substring(with: NSRange(location: read, length: match.range.location - read))
      let groups = (0..<match.numberOfRanges).map { index -> String in
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : source.substring(with: range)
      }
      result += body(groups)
      read = match.range.location + match.range.length
    }
    return result + source.substring(from: read)
  }

  private static func isSensitiveKey(_ key: Any?) -> Bool {
    let lower = describe(key).lowercased()
    return sensitiveBodyKeySubstrings.contains(where: lower.contains) || sensitiveExactKeys.contains(lower)
  }

  private static func namesHeaderCredential(_ name: String) -> Bool {
    let lower = name.lowercased()
    return sensitiveHeaderNameSubstrings.contains(where: lower.contains)
  }

  /// The text Kotlin's `toString` and Dart's `'$value'` answer for `value`, nil included.
  private static func describe(_ value: Any?) -> String {
    guard let value else { return "null" }
    if let text = value as? String { return text }
    if value is NSNull { return "null" }
    return String(describing: value)
  }

  private static func set(_ commaSeparated: String) -> Set<String> {
    Set(commaSeparated.components(separatedBy: ","))
  }
}
