/// A failed request, as ApiClient reports it to a repository.
///
/// Building one logs nothing: the code that catches it logs it once, at the level that fits how it is handled.
///
/// A failed HTTP response also carries its [statusCode], the machine-readable [errorCode] of its body, and how long
/// `Retry-After` asks the client to wait ([retryAfter]); a transport failure has none of them.
abstract class AppException implements Exception {
  final String? _message;
  final String? _prefix;

  /// The HTTP status of the response, or null when no response arrived.
  final int? statusCode;

  /// The string `code` of a JSON error body, such as LibreDB Studio's `AUTH_ERROR` or `RATE_LIMITED`, or null.
  final String? errorCode;

  /// The whole seconds of a `Retry-After` header, or null when it is absent or is an HTTP date.
  final Duration? retryAfter;

  AppException(String? message, String? prefix, {this.statusCode, this.errorCode, this.retryAfter})
    : _message = message,
      _prefix = prefix;

  @override
  String toString() {
    return "$_prefix$_message";
  }
}

class FetchDataException extends AppException {
  FetchDataException(String message, {super.statusCode, super.errorCode, super.retryAfter})
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
  BadRequestException([String? message, int? statusCode, String? errorCode])
    : super(message, "Invalid Request: ", statusCode: statusCode, errorCode: errorCode);
}

final class UnauthorizedException extends AppException {
  UnauthorizedException([String? message, int? statusCode, String? errorCode])
    : super(message, "Unauthorized: ", statusCode: statusCode, errorCode: errorCode);
}

/// Thrown when a circuit breaker is in the OPEN state, rejecting requests
/// to prevent cascading failures against an unhealthy endpoint.
class CircuitBreakerOpenException extends AppException {
  /// The endpoint key whose circuit breaker is open.
  final String endpoint;

  CircuitBreakerOpenException(this.endpoint) : super(endpoint, "Circuit Breaker Open: ");
}
