import 'package:equatable/equatable.dart';

/// Studio's two roles. An admin sees every seed connection of the server without governance; under governance both
/// roles see only their own grants.
enum StudioRole { admin, user }

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
