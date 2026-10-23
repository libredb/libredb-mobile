import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_config.dart';

// A port of Studio's role rules (`shouldMask`, `canToggleMasking`, `canReveal` and `maskingInForce` in
// `src/lib/data-masking.ts:268-296` at libredb-studio c9989a6b5).

/// Whose settings of Studio's `roleSettings` apply.
enum MaskingRoleKind {
  admin,
  user;

  /// The settings [role] gets: the admin the admin settings, and a user, a role this app does not know and no role
  /// (the identity not loaded, or its read failed) the user settings.
  ///
  /// Studio gives every role other than an empty one or `user` the admin settings; the phone gives an unknown role the
  /// user settings on purpose, the least it grants.
  static MaskingRoleKind of(StudioRole? role) => switch (role) {
    null => MaskingRoleKind.user,
    StudioAdminRole() => MaskingRoleKind.admin,
    StudioUserRole() => MaskingRoleKind.user,
    StudioUnknownRole() => MaskingRoleKind.user,
  };
}

MaskingRoleSettings _settings(MaskingRoleKind kind, MaskingConfig config) => switch (kind) {
  MaskingRoleKind.admin => config.roleSettings.admin,
  MaskingRoleKind.user => config.roleSettings.user,
};

/// Whether [kind] masks under [config]: a user who may not toggle always does, else the config decides.
bool shouldMask(MaskingRoleKind kind, MaskingConfig config) => switch (kind) {
  MaskingRoleKind.user => !config.roleSettings.user.canToggle || config.enabled,
  MaskingRoleKind.admin => config.enabled,
};

/// Whether [kind] may turn masking off. No screen offers the toggle before M7-13 (#35).
bool canToggleMasking(MaskingRoleKind kind, MaskingConfig config) => _settings(kind, config).canToggle;

/// Whether [kind] may reveal a masked value. No screen offers it before M7-13 (#35).
bool canReveal(MaskingRoleKind kind, MaskingConfig config) => _settings(kind, config).canReveal;

/// Whether a result masks right now: [kind] and [config] allow it, and the switch [enabled] (or, with none, the
/// config's own flag) has it on.
bool maskingInForce(MaskingRoleKind kind, MaskingConfig config, bool? enabled) =>
    shouldMask(kind, config) && (enabled ?? config.enabled);

/// How one result of one connection is masked: the role's settings of Studio's default config, and the connection's
/// exemption.
///
/// The screen that runs a statement builds it from the role `StudioRoleScope` answers and the
/// `ProviderMeta.maskingExemptColumns` of its connection, masks the first page with it, and hands the same policy on,
/// so every later page of that result is masked alike and never loses the exemption.
class MaskingPolicy extends Equatable {
  const MaskingPolicy._({required this.roleKind, required this.exempt});

  /// The policy for [role], null while the identity is not loaded or its read failed, and the connection's [exempt]
  /// column, if its engine declares one.
  factory MaskingPolicy.forRole(StudioRole? role, {MaskingExemptColumn? exempt}) =>
      MaskingPolicy._(roleKind: MaskingRoleKind.of(role), exempt: exempt);

  final MaskingRoleKind roleKind;
  final MaskingExemptColumn? exempt;

  /// Studio's default config, the only one the phone masks with (S-08).
  MaskingConfig get config => defaultMaskingConfig;

  /// Whether this policy masks: true for every role, since no screen offers the toggle before M7-13 (#35).
  bool get masks => maskingInForce(roleKind, config, null);

  @override
  List<Object?> get props => [roleKind, exempt];
}
