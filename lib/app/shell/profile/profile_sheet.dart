import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

/// What the user picked in the [ProfileSheet]; the caller acts on it once the sheet has closed.
enum ProfileSheetAction { settings, signOut }

/// Who the user is signed in as, by Studio's `GET /api/auth/me`, with the way to the settings and to sign out.
///
/// Studio sends no display name, so the sheet shows the username Studio keys the user by.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key});

  /// Opens the sheet and answers what the user picked, or null when the sheet was dismissed.
  ///
  /// The shell asks for the connection policy only once, so a request that failed is asked again here, where the
  /// governance chip it decides is shown.
  static Future<ProfileSheetAction?> show(BuildContext context) {
    final policy = context.read<ConnectionPolicyCubit>();
    if (policy.state is ConnectionPolicyFailure) policy.load();
    return showModalBottomSheet<ProfileSheetAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const ProfileSheet(),
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
            const _Identity(),
            const _GovernanceChip(),
            const Divider(height: AppSpacing.xl),
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
          StudioIdentityInitial() || StudioIdentityLoading() => (
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            null,
            null,
          ),
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
