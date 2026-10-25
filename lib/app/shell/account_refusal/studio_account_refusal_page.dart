import 'package:flutter/material.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The full-screen page a shell shows in place of every screen while its backend refuses the signed-in account: Studio
/// for the Studio shell, Platform for the Platform shell, each with its own [title].
///
/// It says why, from [errorCode], and offers Retry, which asks the backend again ([retrying] while it does), and
/// Logout. It never retries or signs out by itself.
class StudioAccountRefusalPage extends StatelessWidget {
  const StudioAccountRefusalPage({
    super.key,
    required this.title,
    required this.errorCode,
    required this.retrying,
    required this.onRetry,
    required this.onSignOut,
  });

  /// Which backend refused the account, such as `account_refusal_title` for Studio.
  final String title;

  final AppErrorCode errorCode;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.no_accounts_outlined, size: 64, color: colorScheme.error.withAlpha(179)),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  errorCode.resolve(context),
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  key: accountRefusalRetryKey,
                  onPressed: retrying ? null : onRetry,
                  icon: retrying
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.retry),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: accountRefusalSignOutKey,
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(l10n.logout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
