import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_button.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The full-screen page shown over a signed-in Platform session when Platform does not answer its liveness check.
///
/// It names the configured [host] and offers a retry. It never speaks of the session: nothing about it went wrong, and
/// a retry that reaches Platform opens the app signed in as before.
class PlatformUnreachablePage extends StatelessWidget {
  const PlatformUnreachablePage({super.key, required this.host, required this.error, this.retrying = false});

  /// The host, and the port when the configuration names one, of Platform's API address, or null when none is
  /// configured.
  final String? host;

  /// Why the check failed. Its translated message is added when it has a code, such as an untrusted certificate; its
  /// own text is for the log only.
  final AppError error;

  /// Whether a new check runs, so the retry button shows that it is busy.
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = S.of(context);
    final host = this.host;
    final reason = AppErrorCode.fromKey(error.code)?.resolve(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 80, color: colorScheme.error),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.platform_status_unreachable_title,
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.platform_status_unreachable_message,
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (reason != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  reason,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (host != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.platform_status_unreachable_host(host),
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: l10n.retry,
                icon: Icons.refresh,
                variant: AppButtonVariant.outlined,
                isLoading: retrying,
                onPressed: () => context.read<PlatformStatusBloc>().add(
                  const PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.retry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
