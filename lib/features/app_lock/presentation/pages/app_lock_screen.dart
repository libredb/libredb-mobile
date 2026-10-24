import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The lock screen that covers the app while [AppLockBloc] is locked: Unlock opens the system prompt, and Sign out
/// ([onSignOut], the app's sign-out) lets a user who cannot authenticate leave and wipe the session. A device without a
/// screen lock gets only Sign out.
///
/// The app shows it above its router, so no page is visible or reachable under it.
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key, required this.onSignOut, required this.signingOut});

  final VoidCallback onSignOut;

  /// Whether the sign-out runs, which disables both actions.
  final bool signingOut;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return BlocBuilder<AppLockBloc, AppLockState>(
      builder: (context, state) {
        final (message, isError, canUnlock, authenticating) = switch (state) {
          AppLockLocked(failure: null) => (l10n.app_lock_locked_message, false, true, false),
          AppLockLocked(failure: AppLockFailure.failed) => (l10n.app_lock_failed, true, true, false),
          AppLockLocked(failure: AppLockFailure.lockedOut) => (l10n.app_lock_locked_out, true, true, false),
          AppLockLocked(failure: AppLockFailure.checkFailed) => (l10n.app_lock_check_failed, true, true, false),
          AppLockAuthenticating() => (l10n.app_lock_locked_message, false, true, true),
          AppLockUnavailable(reason: AppLockUnavailableReason.noScreenLock) => (
            l10n.app_lock_no_screen_lock,
            false,
            false,
            false,
          ),
          // Not shown in these states; the app removes the screen.
          AppLockStarting() ||
          AppLockOff() ||
          AppLockUnlocked() ||
          AppLockChecking() ||
          AppLockIdleSigningOut() => (l10n.app_lock_locked_message, false, false, false),
        };
        return Scaffold(
          key: appLockScreenKey,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.lock_outline, size: 56, color: colorScheme.primary),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.app_lock_locked_title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isError ? colorScheme.error : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (canUnlock) ...[
                        FilledButton.icon(
                          key: appLockUnlockKey,
                          onPressed: authenticating || signingOut ? null : () => _unlock(context),
                          icon: const Icon(Icons.fingerprint),
                          label: Text(l10n.app_lock_unlock),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      OutlinedButton(
                        key: appLockSignOutKey,
                        onPressed: authenticating || signingOut ? null : onSignOut,
                        child: signingOut
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.loading),
                              )
                            : Text(l10n.logout),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _unlock(BuildContext context) {
    final l10n = S.of(context);
    context.read<AppLockBloc>().add(
      AppLockUnlockRequested(
        DeviceAuthPrompt(reason: l10n.app_lock_prompt_reason, title: l10n.app_lock_locked_title, cancel: l10n.cancel),
      ),
    );
  }
}
