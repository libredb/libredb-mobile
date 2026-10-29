/// The body of LibreDB Platform's `POST /api/v1/requester/access-requests`: a strict object of exactly `connectionId`,
/// `level` and `reason`, which Platform refuses with any other key.
///
/// [reason] is trimmed before it is sent, because Platform counts its 1 to 500 characters after trimming.
final class AccessRequestCreateBody {
  const AccessRequestCreateBody({required this.connectionId, required this.level, required this.reason});

  final String connectionId;

  /// `read` or `write`; Platform refuses `write` on a connection without a write credential.
  final String level;

  /// Why the user asks. It never reaches a log: the request marks it sensitive, so every exit masks it.
  final String reason;

  /// `{"connectionId": …, "level": …, "reason": "<trimmed>"}` and nothing else.
  Map<String, Object?> toJson() => {'connectionId': connectionId, 'level': level, 'reason': reason.trim()};
}
