import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/session_target_switch_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// What the user picked in the [ProfileSheet]; the caller acts on it once the sheet has closed.
enum ProfileSheetAction { switchMode, settings, signOut }

/// Who the user is signed in as and in which mode, with the way to the other mode, to the settings and to sign out.
///
/// In Studio mode the identity is Studio's `GET /api/auth/me`; Studio sends no display name, so the sheet shows the
/// username Studio keys the user by. In Platform mode it is Platform's `GET /api/v1/me`: the admin's name, or the
/// e-mail when Platform has none, and the tenant; nothing of Studio is read.
///
/// The switch to the other mode is offered only in a build with a Platform target ([PlatformConfigured]); while a
/// switch runs it shows progress and takes no tap.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key, required this.target});

  /// The target of the signed-in session, which decides what the sheet shows.
  final SessionTarget target;

  /// Opens the sheet for a session of [target] and answers what the user picked, or null when the sheet was dismissed.
  ///
  /// The Studio shell asks for the connection policy only once, so a request that failed is asked again here, where
  /// the governance chip it decides is shown.
  static Future<ProfileSheetAction?> show(BuildContext context, {required SessionTarget target}) {
    switch (target) {
      case SessionTarget.studio:
        final policy = context.read<ConnectionPolicyCubit>();
        if (policy.state is ConnectionPolicyFailure) policy.load();
      case SessionTarget.platform:
        break;
    }
    return showModalBottomSheet<ProfileSheetAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ProfileSheet(target: target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...switch (target) {
              SessionTarget.studio => [
                _ModeLabel(l10n.profile_mode_studio),
                const _Identity(),
                const _GovernanceChip(),
              ],
              SessionTarget.platform => [_ModeLabel(l10n.profile_mode_platform), const _PlatformIdentity()],
            },
            const Divider(height: AppSpacing.xl),
            if (context.read<AppConfig>().platform is PlatformConfigured) _SwitchModeTile(target: target),
            ListTile(
              key: profileSettingsKey,
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.settings),
              onTap: () => Navigator.of(context).pop(ProfileSheetAction.settings),
            ),
            ListTile(
              key: profileSignOutKey,
              leading: const Icon(Icons.logout),
              title: Text(l10n.logout),
              onTap: () => Navigator.of(context).pop(ProfileSheetAction.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

/// The way to the mode the session is not in, which shows progress and takes no tap while a switch runs.
class _SwitchModeTile extends StatelessWidget {
  const _SwitchModeTile({required this.target});

  /// The target of the signed-in session, the one the switch leaves.
  final SessionTarget target;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return BlocBuilder<SessionTargetSwitchBloc, SessionTargetSwitchState>(
      builder: (context, state) {
        final running = state is SessionTargetSwitchInProgress;
        return ListTile(
          key: profileSwitchModeKey,
          leading: running
              ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.swap_horiz),
          title: Text(switch (target) {
            SessionTarget.studio => l10n.profile_switch_to_platform,
            SessionTarget.platform => l10n.profile_switch_to_studio,
          }),
          enabled: !running,
          onTap: () => Navigator.of(context).pop(ProfileSheetAction.switchMode),
        );
      },
    );
  }
}

/// The mode the user is signed in to, above the identity.
class _ModeLabel extends StatelessWidget {
  const _ModeLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

/// The signed-in account's icon beside its [title], an optional [subtitle] and an optional [retry].
class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.title, this.subtitle, this.retry});

  final Widget title;
  final Widget? subtitle;
  final Widget? retry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    final retry = this.retry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_circle_outlined, size: 40, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[const SizedBox(height: AppSpacing.xs), subtitle],
                if (retry != null) Align(alignment: AlignmentDirectional.centerStart, child: retry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _identityProgress = Align(
  alignment: AlignmentDirectional.centerStart,
  child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
);

/// Who Platform says the signed-in admin is: the name, or the e-mail when Platform has none, and the tenant.
class _PlatformIdentity extends StatelessWidget {
  const _PlatformIdentity();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<PlatformIdentityCubit, PlatformIdentityState>(
      builder: (context, state) => switch (state) {
        PlatformIdentityInitial() || PlatformIdentityLoading() => const _IdentityRow(title: _identityProgress),
        PlatformIdentityLoaded(:final identity) => _IdentityRow(
          title: Text(identity.name ?? identity.email, style: textTheme.titleMedium),
          subtitle: Text(identity.tenant.name),
        ),
        PlatformIdentityFailure(:final errorCode) => _IdentityRow(
          title: Text(l10n.profile_unknown_user, style: textTheme.titleMedium),
          subtitle: Text(errorCode.resolve(context), style: textTheme.bodySmall?.copyWith(color: colorScheme.error)),
          retry: TextButton(
            key: profileIdentityRetryKey,
            onPressed: () => context.read<PlatformIdentityCubit>().load(),
            child: Text(l10n.retry),
          ),
        ),
      },
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<StudioIdentityCubit, StudioIdentityState>(
      builder: (context, state) {
        final (Widget title, Widget? subtitle, Widget? retry) = switch (state) {
          StudioIdentityInitial() || StudioIdentityLoading() => (_identityProgress, null, null),
          StudioIdentityLoaded(:final identity) => (
            Text(identity.username, style: textTheme.titleMedium),
            Text(_roleLabel(identity.role, l10n)),
            null,
          ),
          StudioIdentityFailure(:final errorCode) => (
            Text(l10n.profile_unknown_user, style: textTheme.titleMedium),
            Text(errorCode.resolve(context), style: textTheme.bodySmall?.copyWith(color: colorScheme.error)),
            TextButton(
              key: profileIdentityRetryKey,
              onPressed: () => context.read<StudioIdentityCubit>().load(),
              child: Text(l10n.retry),
            ),
          ),
        };
        return _IdentityRow(title: title, subtitle: subtitle, retry: retry);
      },
    );
  }

  /// Studio's two roles in the app language, and any other role exactly as Studio sent it, with no invented label.
  static String _roleLabel(StudioRole role, S l10n) => switch (role) {
    StudioAdminRole() => l10n.profile_role_admin,
    StudioUserRole() => l10n.profile_role_user,
    StudioUnknownRole(:final name) => name,
  };
}

/// Shown only when Studio's connection policy says Platform governs it.
class _GovernanceChip extends StatelessWidget {
  const _GovernanceChip();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionPolicyCubit, ConnectionPolicyState>(
      builder: (context, state) {
        final governed = switch (state) {
          ConnectionPolicyLoaded(:final policy) => policy.governance,
          ConnectionPolicyInitial() || ConnectionPolicyLoading() || ConnectionPolicyFailure() => false,
        };
        if (!governed) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.md),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(
              avatar: const Icon(Icons.verified_user_outlined, size: 18),
              label: Text(S.of(context).profile_governed_by_platform),
            ),
          ),
        );
      },
    );
  }
}
