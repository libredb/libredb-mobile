import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/core/security/sensitive_data_scrubber.dart';

/// A grant of one connection as LibreDB Platform's `GET /api/v1/connections/{id}/grants` lists it (libredb-platform
/// `src/features/connections/lib/grant-service.ts`): a Keycloak user's access to the connection.
///
/// [level] is opaque: `read` and `write` today, and an unknown value is kept as Platform sent it. An expired grant is
/// still listed by Platform, so [isExpiredAt] tells it apart.
final class PlatformGrant extends Equatable {
  const PlatformGrant({
    required this.id,
    required this.subject,
    required this.subjectUsername,
    required this.subjectEmail,
    required this.level,
    required this.expiresAt,
    required this.grantedBy,
    required this.grantedAt,
  });

  /// The grant id, which a revoke names; never the subject.
  final String id;

  /// The Keycloak user id of the person who holds the grant.
  final String subject;

  final String subjectUsername;

  /// Null when Keycloak has no e-mail address for the user.
  final String? subjectEmail;

  final String level;

  /// Null for a grant that does not expire.
  final DateTime? expiresAt;

  /// The Platform user who last set the grant, at [grantedAt].
  final PlatformGrantGranter grantedBy;

  final DateTime grantedAt;

  /// Whether the grant has expired at [now]: its expiry is at or before [now].
  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(now);
  }

  @override
  List<Object?> get props => [id, subject, subjectUsername, subjectEmail, level, expiresAt, grantedBy, grantedAt];

  /// No username, name or e-mail address: this text can reach a log.
  @override
  String toString() => 'PlatformGrant(id: $id, level: $level, expiresAt: $expiresAt, email: $secretMask)';
}

/// The Platform user who set a grant.
final class PlatformGrantGranter extends Equatable {
  const PlatformGrantGranter({required this.id, required this.name, required this.email});

  final String id;

  /// Null when the Platform user has no name.
  final String? name;

  final String email;

  @override
  List<Object?> get props => [id, name, email];

  /// No name or e-mail address: this text can reach a log.
  @override
  String toString() => 'PlatformGrantGranter(id: $id)';
}
