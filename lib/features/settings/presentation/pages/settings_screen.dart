import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/settings/application/remove_my_data_bloc.dart';
import 'package:libredb_mobile/features/settings/presentation/widgets/remove_my_data_dialog.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/l10n/locale_l10n.dart';
import 'package:libredb_mobile/shared/user_data/signed_in_account_scope.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';
import 'package:libredb_mobile/shared/utils/app_constants.dart';
import 'package:libredb_mobile/shared/utils/external_link.dart';
import 'package:libredb_mobile/shared/widgets/language_selection_dialog.dart';
import 'package:libredb_mobile/shared/widgets/theme_selection_dialog.dart';

import '../../../../generated/l10n.dart';
import '../../../../infrastructure/config/project_links.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context).settings,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                S.of(context).settings_subtitle,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),

              const SizedBox(height: AppSpacing.lg),

              // Appearance section
              _SettingsSection(
                title: S.of(context).settings_appearance,
                children: [
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: S.of(context).theme,
                    subtitle: S.of(context).settings_theme_subtitle,
                    onTap: () => ThemeSelectionDialog.show(context),
                  ),
                  _SettingsTile(
                    key: settingsChangeLanguageButtonKey,
                    icon: Icons.translate,
                    title: S.of(context).language,
                    subtitle: Localizations.localeOf(context).displayName(context),
                    onTap: () => LanguageSelectionDialog.show(context),
                  ),
                ],
              ),

              // Privacy section, while Studio names the signed-in account
              if (SignedInAccountScope.of(context).subject != null) ...[
                const SizedBox(height: AppSpacing.lg),
                const _PrivacySection(),
              ],

              // Help & Resources section
              const SizedBox(height: AppSpacing.lg),
              _SettingsSection(
                title: S.of(context).help_resources,
                children: [
                  _SettingsTile(
                    key: settingsWebsiteButtonKey,
                    icon: Icons.language,
                    title: S.of(context).documentation,
                    subtitle: S.of(context).help_resources_subtitle,
                    onTap: () => openExternalLink(context, Uri.parse(context.read<ProjectLinks>().docsUrl)),
                  ),
                  _SettingsTile(
                    key: settingsLicensesButtonKey,
                    icon: Icons.gavel_outlined,
                    title: S.of(context).settings_licenses,
                    subtitle: S.of(context).settings_licenses_subtitle,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: AppConstants.appVersion,
                    ),
                  ),
                ],
              ),
              // Logout intentionally lives only in the profile sheet of
              // the shell, not here. Settings is feature-scoped and an
              // auth-session lifecycle action would cross feature
              // boundaries (architecture guard rejects features/settings
              // → features/auth imports). 'Remove my data' signs out
              // through the SignedInAccountScope the shell provides.
            ],
          ),
        ),
      ),
    );
  }
}

/// 'Remove my data': clears what the phone keeps for the signed-in account, then signs out; a store that fails keeps
/// the user signed in with the failure and a retry.
class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return BlocProvider<RemoveMyDataBloc>(
      create: (context) => RemoveMyDataBloc(registry: context.read<UserDataRegistry>()),
      child: BlocConsumer<RemoveMyDataBloc, RemoveMyDataState>(
        listenWhen: (previous, current) => current is RemoveMyDataDone || current is RemoveMyDataFailure,
        listener: (context, state) => switch (state) {
          RemoveMyDataDone() => SignedInAccountScope.read(context).signOut(),
          // The user stays signed in: what the app holds in memory follows what is left, so it never writes back what
          // was cleared.
          RemoveMyDataFailure() => SignedInAccountScope.read(context).reloadStoredData(),
          RemoveMyDataIdle() || RemoveMyDataInProgress() => null,
        },
        builder: (context, state) {
          // Once done, the shell's sign-out barrier covers the page until the login page opens.
          final (clearing, enabled) = switch (state) {
            RemoveMyDataInProgress() => (true, false),
            RemoveMyDataDone() => (false, false),
            RemoveMyDataIdle() || RemoveMyDataFailure() => (false, true),
          };
          return _SettingsSection(
            title: l10n.settings_privacy,
            children: [
              _SettingsTile(
                key: settingsRemoveMyDataKey,
                icon: Icons.delete_forever_outlined,
                title: l10n.remove_my_data,
                subtitle: l10n.remove_my_data_subtitle,
                trailing: clearing
                    ? SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          key: removeMyDataProgressKey,
                          strokeWidth: 2,
                          semanticsLabel: l10n.loading,
                        ),
                      )
                    : null,
                onTap: enabled ? () => _confirm(context) : null,
              ),
              if (state case RemoveMyDataFailure(:final errorCode))
                _RemoveMyDataFailure(message: errorCode.resolve(context), onRetry: () => _remove(context)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    if (!await RemoveMyDataDialog.show(context) || !context.mounted) return;
    _remove(context);
  }

  /// Clears the data of the account Studio names now, so a retry follows the account that is signed in.
  void _remove(BuildContext context) {
    final subject = SignedInAccountScope.read(context).subject;
    if (subject == null) return;
    context.read<RemoveMyDataBloc>().add(RemoveMyDataRequested(subject: subject));
  }
}

/// The failure of 'Remove my data', which names no store or stored value, with a retry.
class _RemoveMyDataFailure extends StatelessWidget {
  const _RemoveMyDataFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
          ),
          TextButton(key: removeMyDataRetryKey, onPressed: onRetry, child: Text(S.of(context).retry)),
        ],
      ),
    );
  }
}

/// A grouped settings section with a title and list of tiles.
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text(
            title,
            style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Individual settings tile with icon, title, subtitle, and navigation.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Shown in place of the chevron, such as a progress indicator while the tile's action runs.
  final Widget? trailing;

  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
