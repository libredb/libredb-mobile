import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';

/// The person a grant names, as the grant editor shows them: from the directory user the admin picked, or from the
/// grant being changed when the editor opens from the grants list.
///
/// [studioRole], [enabled] and [needsSeat] are known only for a user from the directory; [fromDirectory] tells.
final class GrantSubject extends Equatable {
  const GrantSubject({
    required this.subject,
    required this.username,
    required this.email,
    required this.fullName,
    required this.fromDirectory,
    this.studioRole,
    this.needsSeat = false,
  });

  GrantSubject.ofUser(DirectoryUser user)
    : this(
        subject: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        fromDirectory: true,
        studioRole: user.studioRole,
        needsSeat: user.needsSeat,
      );

  GrantSubject.ofGrant(PlatformGrant grant)
    : this(
        subject: grant.subject,
        username: grant.subjectUsername,
        email: grant.subjectEmail,
        fullName: null,
        fromDirectory: false,
      );

  /// The Keycloak user id, the path segment of the grant `PUT`.
  final String subject;
  final String username;
  final String? email;
  final String? fullName;
  final bool fromDirectory;
  final String? studioRole;
  final bool needsSeat;

  @override
  List<Object?> get props => [subject, username, email, fullName, fromDirectory, studioRole, needsSeat];

  /// No id, username, name or e-mail address: this text can reach a log.
  @override
  String toString() => 'GrantSubject(fromDirectory: $fromDirectory, studioRole: $studioRole, needsSeat: $needsSeat)';
}
