import 'package:equatable/equatable.dart';

/// A role as Studio's `GET /api/auth/me` names it, the only source of the app's role.
///
/// Studio has two roles, [StudioAdminRole] and [StudioUserRole]: an admin sees every seed connection of the server
/// without governance, and under governance both roles see only their own grants. A newer Studio may name another,
/// which is a [StudioUnknownRole] and gets the least the app grants. Every decision on a role is an exhaustive `switch`
/// with no wildcard, so a variant added later stops the build at each decision point.
sealed class StudioRole extends Equatable {
  const StudioRole();

  /// The role Studio calls [name], compared exactly as Studio does (`role === "admin"`), never case-folded.
  factory StudioRole.fromName(String name) => switch (name) {
    StudioAdminRole.wireName => const StudioAdminRole(),
    StudioUserRole.wireName => const StudioUserRole(),
    _ => StudioUnknownRole(name),
  };

  /// The role exactly as Studio sent it.
  String get name;

  @override
  List<Object?> get props => [name];
}

/// Studio's `admin`.
final class StudioAdminRole extends StudioRole {
  const StudioAdminRole();

  static const wireName = 'admin';

  @override
  String get name => wireName;
}

/// Studio's `user`.
final class StudioUserRole extends StudioRole {
  const StudioUserRole();

  static const wireName = 'user';

  @override
  String get name => wireName;
}

/// A role this app does not know, kept as Studio sent it.
final class StudioUnknownRole extends StudioRole {
  const StudioUnknownRole(this.name);

  @override
  final String name;
}

/// Who Studio says the signed-in user is: the answer of `GET /api/auth/me`.
class StudioIdentity extends Equatable {
  const StudioIdentity({
    required this.username,
    required this.role,
    this.subject,
    this.issuer,
    this.expiresAt,
    this.viaBearer = false,
  });

  /// The name Studio keys the user by: the verified email, else the preferred username.
  final String username;
  final StudioRole role;

  /// The identity provider's `sub` and `iss`, which Platform's grants are written against.
  final String? subject;
  final String? issuer;

  /// When the session Studio sees ends: the access token's `exp` for a bearer session.
  final DateTime? expiresAt;

  /// Whether Studio accepted the request through its bearer channel, as it does for this app.
  final bool viaBearer;

  @override
  List<Object?> get props => [username, role, subject, issuer, expiresAt, viaBearer];
}
