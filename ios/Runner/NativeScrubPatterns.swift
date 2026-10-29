import Foundation

/// Copies of the scrub policy in lib/core/security/sensitive_data_scrubber.dart and
/// lib/infrastructure/analytics/sentry_scrub.dart, which `NativeSentryScrubber` masks native Sentry events and
/// breadcrumbs with.
///
/// Each pattern is a raw string, which Swift reads without escape processing, so its text is the Dart pattern byte
/// for byte, as the Kotlin copy in android/app/src/main/kotlin/org/libredb/mobile/NativeScrubPatterns.kt is.
/// test/architecture/sentry_native_scrub_patterns_test.dart fails when a pattern, a set or a mask here differs from
/// the Dart one: change both together.
enum NativeScrubPatterns {
  static let jwtPattern = #"eyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}"#
  static let emailPattern = #"[A-Za-z0-9._%+-]{1,64}(?:@|%40)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"#
  static let jsonMemberPattern = #""([^"\\]{1,64})"([\t\n\u000b\f\r \u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]*:[\t\n\u000b\f\r \u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]*)("(?:[^"\\]|\\[^\n\r\u2028\u2029])*"|-?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)"#
  static let namedValuePattern = #"(?<![A-Za-z0-9_.\-])([A-Za-z_][A-Za-z0-9_.\-]{0,63})=([^\[&\t\n\u000b\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff#"',;)}\]][^&\t\n\u000b\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff#"',;)}\]]*)"#
  static let bearerPattern = #"(?<![A-Za-z0-9_])([Bb][Ee][Aa][Rr][Ee][Rr])[\t\n\u000b\f\r \u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+[A-Za-z0-9\-._~+/]+=*"#

  // Comma-separated, compared as sets by the guard test.
  static let sensitiveHeaderNames = "authorization,cookie,set-cookie"
  static let sensitiveHeaderNameSubstrings = "authorization,api-key,api_key,apikey"
  static let sensitiveBodyKeySubstrings = "password,otp,token,refreshtoken,secret,subjectemail,requesteremail,reason,statement,errormessage"
  static let sensitiveExactKeys = "code,code_verifier,state,nonce,session_state,id_token_hint"
  static let navigationTypes = "didPush,didPop,didReplace"

  static let secretMask = "[REDACTED]"
  static let jwtMask = "[REDACTED_JWT]"
  static let emailMask = "[REDACTED_EMAIL]"
}
