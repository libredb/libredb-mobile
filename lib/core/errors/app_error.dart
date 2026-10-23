/// Typed error hierarchy for structured error handling.
///
/// Used with [Result] type instead of throwing exceptions.
sealed class AppError {
  const AppError(this.message, {this.code});
  final String message;
  final String? code;

  @override
  bool operator ==(Object other) => other is AppError && other.message == message && other.code == code;

  @override
  int get hashCode => Object.hash(message, code);

  @override
  String toString() => '$runtimeType($message${code != null ? ', code: $code' : ''})';
}

/// Network connectivity error (no internet, DNS failure).
final class NetworkError extends AppError {
  const NetworkError(super.message, {super.code});
}

/// Authentication/authorization error (401, 403, expired token).
///
/// [fixStatement] is a statement the server offers to fix a refused database credential, for the user to copy.
final class AuthError extends AppError {
  const AuthError(super.message, {super.code, this.fixStatement});

  final String? fixStatement;

  @override
  bool operator ==(Object other) => other is AuthError && super == other && other.fixStatement == fixStatement;

  @override
  int get hashCode => Object.hash(super.hashCode, fixStatement);
}

/// Input validation error (invalid form data, bad request params).
///
/// [position] is where the database placed the error of a statement, counted in characters from 1 as the database
/// reported it, when it reported one.
final class ValidationError extends AppError {
  const ValidationError(super.message, {super.code, this.position});

  final int? position;

  @override
  bool operator ==(Object other) => other is ValidationError && super == other && other.position == position;

  @override
  int get hashCode => Object.hash(super.hashCode, position);
}

/// Server-side error (500, 502, 503).
final class ServerError extends AppError {
  const ServerError(super.message, {super.code});
}

/// Resource not found (404).
final class NotFoundError extends AppError {
  const NotFoundError(super.message, {super.code});
}

/// Request timeout. [sent] is false for a timeout while connecting or sending, when the server never received the
/// request.
final class TimeoutError extends AppError {
  const TimeoutError(super.message, {super.code, this.sent = true});

  final bool sent;

  @override
  bool operator ==(Object other) => other is TimeoutError && super == other && other.sent == sent;

  @override
  int get hashCode => Object.hash(super.hashCode, sent);
}

/// The server refused the request because the client sent too many (429). [retryAfter] is how long it asked the client
/// to wait, when it said.
final class RateLimitedError extends AppError {
  const RateLimitedError(super.message, {super.code, this.retryAfter});

  final Duration? retryAfter;
}

/// A request the app dropped itself: the user cancelled it or left the page that waited for it. No screen shows it as
/// an error; it carries no code.
final class RequestCancelledError extends AppError {
  const RequestCancelledError(super.message);
}

/// Unknown/unexpected error.
final class UnknownError extends AppError {
  const UnknownError(super.message, {super.code});
}
