import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/widgets/platform_identity_scope.dart';

/// The home tab of Platform mode: the install's tenant and the signed-in admin, from the identity the Platform shell
/// holds ([PlatformIdentityScope]), and a shortcut to the connections. It sends no request of its own.
class PlatformHomePage extends StatelessWidget {
  const PlatformHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = PlatformIdentityScope.of(context);
    final identity = scope.identity;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (identity != null)
          _IdentityCard(identity: identity)
        else if (scope.failed)
          AppErrorState(title: s.platform_home_identity_load_failed, retryLabel: s.retry, onRetry: scope.onRetry)
        else
          const _IdentitySkeleton(),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          key: const ValueKey('platform-home-connections'),
          onTap: () => context.go(ApplicationRoutesConstants.platformConnections),
          child: Row(
            children: [
              Icon(Icons.storage_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.platform_home_connections_shortcut, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      s.platform_home_connections_shortcut_description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.identity});

  final PlatformIdentity identity;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return AppCard(
      key: const ValueKey('platform-home-identity'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.platform_home_tenant_label, style: muted),
          const SizedBox(height: AppSpacing.xs),
          Text(identity.tenant.name, style: textTheme.titleMedium),
          Text(identity.tenant.slug, style: muted),
          const SizedBox(height: AppSpacing.lg),
          Text(s.platform_home_signed_in_as, style: muted),
          const SizedBox(height: AppSpacing.xs),
          Text(identity.name ?? identity.email, style: textTheme.titleSmall),
          Text(s.platform_home_admin_label, style: muted),
        ],
      ),
    );
  }
}

class _IdentitySkeleton extends StatelessWidget {
  const _IdentitySkeleton();

  @override
  Widget build(BuildContext context) => const AppSkeleton.card(key: ValueKey('platform-home-identity-skeleton'));
}
