import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
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
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onSignOut, required this.signingOut});

  final VoidCallback onSignOut;

  /// Whether the sign-out runs, which disables both actions.
  final bool signingOut;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static final _log = AppLogger.getLogger('AppLockScreen');

  /// How long the platform may take to name the biometric before the screen names only the screen lock.
  static const _biometricTimeout = Duration(seconds: 3);

  /// The biometric the device has, null until the platform has answered, so the screen shows no icon that it would
  /// have to swap.
  DeviceBiometric? _biometric;

  @override
  void initState() {
    super.initState();
    unawaited(_askBiometric());
  }

  Future<void> _askBiometric() async {
    DeviceBiometric answer;
    try {
      answer = await context.read<IDeviceAuthenticator>().availableBiometric().timeout(_biometricTimeout);
    } catch (e) {
      // A failed or slow answer names no biometric, since claiming a wrong one is worse than naming only the lock.
      _log.warn('the device did not name its biometric, so the screen names only the screen lock: {}', [e]);
      answer = DeviceBiometric.none;
    }
    if (mounted) setState(() => _biometric = answer);
  }

  @override
  Widget build(BuildContext context) {
    final onSignOut = widget.onSignOut;
    final signingOut = widget.signingOut;
    final biometric = _biometric;
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return BlocBuilder<AppLockBloc, AppLockState>(
      builder: (context, state) {
        final (message, isError, canUnlock, authenticating) = switch (state) {
          AppLockLocked(failure: null) => (_lockedMessage(l10n, biometric), false, true, false),
          AppLockLocked(failure: AppLockFailure.failed) => (l10n.app_lock_failed, true, true, false),
          AppLockLocked(failure: AppLockFailure.lockedOut) => (l10n.app_lock_locked_out, true, true, false),
          AppLockLocked(failure: AppLockFailure.checkFailed) => (l10n.app_lock_check_failed, true, true, false),
          AppLockAuthenticating() => (_lockedMessage(l10n, biometric), false, true, true),
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
                      // The wording that names the biometric waits for the answer, keeping its space.
                      Visibility(
                        visible: biometric != null || isError || !canUnlock,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isError ? colorScheme.error : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (canUnlock) ...[
                        FilledButton.icon(
                          key: appLockUnlockKey,
                          onPressed: authenticating || signingOut ? null : () => _unlock(context),
                          icon: biometric == null
                              ? const SizedBox.square(dimension: 18)
                              : Icon(_biometricIcon(biometric)),
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

  static String _lockedMessage(S l10n, DeviceBiometric? biometric) => switch (biometric) {
    DeviceBiometric.face => l10n.app_lock_locked_message_face,
    DeviceBiometric.fingerprint => l10n.app_lock_locked_message_fingerprint,
    DeviceBiometric.iris => l10n.app_lock_locked_message_iris,
    DeviceBiometric.several => l10n.app_lock_locked_message_several,
    DeviceBiometric.none || null => l10n.app_lock_locked_message,
  };

  /// The icon of the biometric the device has; several kinds or none get a neutral one that claims no kind.
  static IconData _biometricIcon(DeviceBiometric biometric) => switch (biometric) {
    DeviceBiometric.face => Icons.face_unlock_outlined,
    DeviceBiometric.fingerprint => Icons.fingerprint,
    DeviceBiometric.iris => Icons.remove_red_eye_outlined,
    DeviceBiometric.several || DeviceBiometric.none => Icons.lock_open_outlined,
  };

  void _unlock(BuildContext context) {
    final l10n = S.of(context);
    context.read<AppLockBloc>().add(
      AppLockUnlockRequested(
        DeviceAuthPrompt(reason: l10n.app_lock_prompt_reason, title: l10n.app_lock_locked_title, cancel: l10n.cancel),
      ),
    );
  }
}
