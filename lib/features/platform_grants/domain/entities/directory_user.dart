import 'package:equatable/equatable.dart';

/// A Keycloak user as LibreDB Platform's directory search lists it (`GET /api/v1/directory/users`, libredb-platform
/// `src/features/connections/lib/grant.schema.ts`): a person a grant can name.
///
/// [id] is the Keycloak user id, which a grant's subject is; it is opaque and may hold a `:`, such as
/// `f:<component>:<username>` for an LDAP user without import. [studioRole] is opaque too: `admin`, `user`, null for a
/// user who holds neither role and cannot sign in to Studio, and an unknown value is kept as Platform sent it.
final class DirectoryUser extends Equatable {
  const DirectoryUser({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.enabled,
    required this.studioRole,
    required this.needsSeat,
  });

  final String id;
  final String username;

  /// Null when Keycloak has no e-mail address for the user.
  final String? email;
  final String? firstName;
  final String? lastName;

  /// False for a user disabled in Keycloak, whom Platform refuses as a grant's subject.
  final bool enabled;

  final String? studioRole;

  /// Whether a grant on an active connection would take one of the license's user seats.
  final bool needsSeat;

  /// The first and last name joined, or null when Keycloak has neither.
  String? get fullName {
    final name = [firstName, lastName].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? null : name;
  }

  @override
  List<Object?> get props => [id, username, email, firstName, lastName, enabled, studioRole, needsSeat];

  /// No id, username, name or e-mail address: this text can reach a log.
  @override
  String toString() => 'DirectoryUser(enabled: $enabled, studioRole: $studioRole, needsSeat: $needsSeat)';
}
