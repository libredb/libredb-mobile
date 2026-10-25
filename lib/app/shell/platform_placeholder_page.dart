import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The page of both Platform tabs until the Platform home and connection list replace it: who Platform says the
/// signed-in admin is, the name or the e-mail when Platform has none, and the tenant.
///
/// It lives in the app layer, not in a Platform feature, because a feature may not read [PlatformIdentityCubit] from
/// the auth feature.
class PlatformPlaceholderPage extends StatelessWidget {
  const PlatformPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<PlatformIdentityCubit, PlatformIdentityState>(
      builder: (context, state) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: switch (state) {
              PlatformIdentityInitial() ||
              PlatformIdentityLoading() => [CircularProgressIndicator(semanticsLabel: l10n.loading)],
              PlatformIdentityLoaded(:final identity) => [
                Icon(Icons.admin_panel_settings_outlined, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.platform_placeholder_title, style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(identity.name ?? identity.email, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(identity.tenant.name, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.platform_placeholder_note,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              PlatformIdentityFailure(:final errorCode) => [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: AppSpacing.md),
                Text(errorCode.resolve(context), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => context.read<PlatformIdentityCubit>().load(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.retry),
                ),
              ],
            },
          ),
        ),
      ),
    );
  }
}
