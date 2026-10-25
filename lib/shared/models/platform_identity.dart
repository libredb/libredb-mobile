import 'package:equatable/equatable.dart';

/// Who LibreDB Platform says the signed-in admin is: the answer of `GET /api/v1/me` (libredb-platform
/// `src/app/api/v1/me/route.ts`).
///
/// It is held in memory only and never stored. [id] is Platform's user id, not the identity provider's `sub`, so it
/// never keys a store on the device. [roles] and [permissions] are opaque strings, kept as Platform sent them, an
/// unknown value included; Platform's answer never decides a Studio role.
class PlatformIdentity extends Equatable {
  const PlatformIdentity({
    required this.id,
    required this.email,
    this.name,
    required this.roles,
    required this.permissions,
    required this.tenant,
  });

  final String id;
  final String email;

  /// The display name, which Platform may not have.
  final String? name;
  final List<String> roles;
  final List<String> permissions;

  /// The install's tenant the admin works in.
  final PlatformTenant tenant;

  @override
  List<Object?> get props => [id, email, name, roles, permissions, tenant];

  /// Neither the e-mail nor the name: this text can reach a log.
  @override
  String toString() => 'PlatformIdentity(id: $id, roles: $roles, tenant: ${tenant.slug})';
}

/// The tenant of a [PlatformIdentity].
class PlatformTenant extends Equatable {
  const PlatformTenant({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  @override
  List<Object?> get props => [id, name, slug];
}
