/// A failed request, as ApiClient reports it to a repository.
///
/// Building one logs nothing: the code that catches it logs it once, at the level that fits how it is handled.
///
/// A failed HTTP response also carries its [statusCode], the machine-readable [errorCode] and the [serverMessage] of its
/// body, and how long `Retry-After` asks the client to wait ([retryAfter]); a transport failure has none of them.
abstract class AppException implements Exception {
  final String? _message;
  final String? _prefix;

  /// The HTTP status of the response, or null when no response arrived.
  final int? statusCode;

  /// The string `code` of a JSON error body, such as LibreDB Studio's `AUTH_ERROR` or `RATE_LIMITED`, or null.
  final String? errorCode;

  /// The whole seconds of a `Retry-After` header, or null when it is absent or is an HTTP date.
  final Duration? retryAfter;

  /// The string `error` of a JSON error body, scrubbed of the request's secrets like the rest of the body, or null.
  ///
  /// It is the server's own words, such as a database's syntax error, for a screen whose purpose is to show them; any
  /// other screen shows a translated message for [errorCode] instead.
  final String? serverMessage;

  /// The string `fixStatement` of a JSON error body, scrubbed like [serverMessage], or null.
  ///
  /// LibreDB Studio sends it with a 401 `AUTH_ERROR` when the database names a statement that fixes the refusal, for
  /// the user to copy (`src/lib/api/error-body.ts` in Studio).
  final String? fixStatement;

  AppException(
    String? message,
    String? prefix, {
    this.statusCode,
    this.errorCode,
    this.retryAfter,
    this.serverMessage,
    this.fixStatement,
  }) : _message = message,
       _prefix = prefix;

  @override
  String toString() {
    return "$_prefix$_message";
  }
}

class FetchDataException extends AppException {
  FetchDataException(String message, {super.statusCode, super.errorCode, super.retryAfter, super.serverMessage})
    : super(message, "Error During Communication: ");
}

/// Thrown when the connection could not be verified as secure: the server
/// presents a certificate that matches none of the configured certificate
/// pins, or one the device does not trust (expired, self-signed, issued for
/// another host, or presented by a captive portal or an intercepting proxy),
/// or the TLS handshake was closed before it completed ("Connection
/// terminated during handshake"). The connection may be intercepted.
///
/// A repository should report it with `AppErrorCode.networkCertInvalid` so
/// the UI can show a translated message. The message of this exception names the
/// host and port and the TLS error, and is meant for the log.
final class UntrustedCertificateException extends FetchDataException {
  UntrustedCertificateException(super.message);
}

final class BadRequestException extends AppException {
  BadRequestException(String? message, {super.statusCode, super.errorCode, super.serverMessage})
    : super(message, "Invalid Request: ");
}

final class UnauthorizedException extends AppException {
  UnauthorizedException(String? message, {super.statusCode, super.errorCode, super.serverMessage, super.fixStatement})
    : super(message, "Unauthorized: ");
}

/// Thrown when a circuit breaker is in the OPEN state, rejecting requests
/// to prevent cascading failures against an unhealthy endpoint.
class CircuitBreakerOpenException extends AppException {
  /// The endpoint key whose circuit breaker is open.
  final String endpoint;

  CircuitBreakerOpenException(this.endpoint) : super(endpoint, "Circuit Breaker Open: ");
}
