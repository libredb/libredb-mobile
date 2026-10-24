import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_settings_bloc.dart';
import 'package:libredb_mobile/features/app_lock/domain/entities/app_lock_settings.dart';
import 'package:libredb_mobile/features/app_lock/domain/repositories/app_lock_settings_repository.dart';
import 'package:libredb_mobile/features/app_lock/domain/services/device_authenticator.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The app lock rows of the settings' Security section: the switch and the timeout.
///
/// Turning the lock on asks the system prompt first; a device without a screen lock shows why the switch cannot be
/// turned on. A build with `APP_LOCK_REQUIRED` shows the switch on and disabled.
class AppLockSettingsSection extends StatelessWidget {
  const AppLockSettingsSection({super.key});

  /// The label of [timeout].
  static String timeoutLabel(S l10n, AppLockTimeout timeout) => switch (timeout) {
    AppLockTimeout.immediately => l10n.app_lock_timeout_immediately,
    AppLockTimeout.oneMinute => l10n.app_lock_timeout_one_minute,
    AppLockTimeout.fiveMinutes => l10n.app_lock_timeout_five_minutes,
    AppLockTimeout.fifteenMinutes => l10n.app_lock_timeout_fifteen_minutes,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppLockSettingsBloc>(
      create: (context) => AppLockSettingsBloc(
        repository: context.read<IAppLockSettingsRepository>(),
        authenticator: context.read<IDeviceAuthenticator>(),
      )..add(const AppLockSettingsOpened()),
      child: BlocListener<AppLockSettingsBloc, AppLockSettingsState>(
        listenWhen: (previous, current) => current is AppLockSettingsSaved,
        listener: (context, state) =>
            context.read<AppLockBloc>().add(AppLockSettingsChanged((state as AppLockSettingsSaved).settings)),
        child: const _AppLockRows(),
      ),
    );
  }
}

class _AppLockRows extends StatelessWidget {
  const _AppLockRows();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final required = context.read<AppConfig>().appLockRequired;
    final settings = switch (context.watch<AppLockBloc>().state) {
      AppLockSettled(:final settings) => settings,
      AppLockStarting() => null,
    };
    final sectionState = context.watch<AppLockSettingsBloc>().state;
    final (canAuthenticate, busy) = switch (sectionState) {
      AppLockSettingsChecking() => (false, true),
      AppLockSettingsSaving(:final canAuthenticate) => (canAuthenticate, true),
      AppLockSettingsChecked(:final canAuthenticate) => (canAuthenticate, false),
    };
    final enabled = settings?.enabled ?? false;
    final isOn = required || enabled;
    final subtitle = switch ((required, canAuthenticate || enabled || busy)) {
      (true, _) => l10n.app_lock_required_subtitle,
      (false, false) => l10n.app_lock_no_screen_lock_subtitle,
      (false, true) => l10n.app_lock_subtitle,
    };
    // Turning it on needs a screen lock; turning it off never does.
    final canToggle = !required && settings != null && !busy && (enabled || canAuthenticate);
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    return Column(
      children: [
        SwitchListTile(
          key: appLockSwitchKey,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          secondary: Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant),
          title: Text(l10n.app_lock),
          subtitle: Text(subtitle, style: subtitleStyle),
          value: isOn,
          onChanged: canToggle ? (value) => _change(context, settings, settings.copyWith(enabled: value)) : null,
        ),
        Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg, color: colorScheme.outlineVariant),
        ListTile(
          key: appLockTimeoutKey,
          enabled: isOn && settings != null && !busy,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          leading: Icon(Icons.timer_outlined, color: colorScheme.onSurfaceVariant),
          title: Text(l10n.app_lock_timeout),
          subtitle: Text(
            AppLockSettingsSection.timeoutLabel(l10n, settings?.timeout ?? AppLockSettings.defaults.timeout),
            style: subtitleStyle,
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          onTap: settings == null ? null : () => _pickTimeout(context, settings),
        ),
        if (sectionState case AppLockSettingsFailure(:final errorCode))
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    errorCode.resolve(context),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _change(BuildContext context, AppLockSettings current, AppLockSettings next) {
    final l10n = S.of(context);
    context.read<AppLockSettingsBloc>().add(
      AppLockSettingsChangeRequested(
        current: current,
        next: next,
        prompt: DeviceAuthPrompt(reason: l10n.app_lock_enable_reason, title: l10n.app_lock, cancel: l10n.cancel),
      ),
    );
  }

  Future<void> _pickTimeout(BuildContext context, AppLockSettings current) async {
    final l10n = S.of(context);
    final picked = await showDialog<AppLockTimeout>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.app_lock_timeout),
        children: [
          for (final timeout in AppLockTimeout.values)
            ListTile(
              key: ValueKey('appLockTimeout_${timeout.name}'),
              title: Text(AppLockSettingsSection.timeoutLabel(l10n, timeout)),
              trailing: timeout == current.timeout ? const Icon(Icons.check) : null,
              selected: timeout == current.timeout,
              onTap: () => Navigator.of(dialogContext).pop(timeout),
            ),
        ],
      ),
    );
    if (picked == null || picked == current.timeout || !context.mounted) return;
    _change(context, current, current.copyWith(timeout: picked));
  }
}
