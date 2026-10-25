import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/app/shell/sign_out_flow.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/session_target_switch_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/widgets/confirmation_dialog_widget.dart';
import 'package:libredb_mobile/shared/widgets/unsaved_changes_guard.dart';

/// The one top bar of the shell: a back arrow on a page that is no tab, the page title, and the avatar that opens the
/// profile sheet.
class TopBarWidget extends StatelessWidget {
  /// The target of the shell, whose profile sheet and settings the avatar opens.
  final SessionTarget target;

  final String title;

  /// Returns from a page that is no tab; null on a tab, which has no back arrow.
  final VoidCallback? onBack;

  /// Shown in place of [title] when set, such as the active connection on a tab that works on it.
  final Widget? titleWidget;

  const TopBarWidget({super.key, required this.target, required this.title, this.onBack, this.titleWidget});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final back = onBack;

    return Container(
      height: 48, // h-12
      padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          if (back != null) BackButton(onPressed: back) else const SizedBox(width: 8),
          // Takes the width that the avatar leaves, and is shortened when that is too little.
          Expanded(
            child:
                titleWidget ??
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          ),
          IconButton(
            key: profileButtonKey,
            tooltip: S.of(context).profile,
            icon: Icon(Icons.account_circle_outlined, color: cs.onSurfaceVariant),
            onPressed: () => _openProfile(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    final action = await ProfileSheet.show(context, target: target);
    if (action == null || !context.mounted) return;
    switch (action) {
      case ProfileSheetAction.settings:
        final router = GoRouter.of(context);
        // Stacks on the open tab, so the back arrow returns to it; on the settings it stays.
        final settings = ApplicationRoutesConstants.settingsFor(target);
        if (router.state.uri.path != settings) router.push(settings);
      case ProfileSheetAction.switchMode:
        await _switchMode(context);
      case ProfileSheetAction.signOut:
        await confirmAndSignOut(context);
    }
  }

  /// Switches the session to the other target once the user agreed: a switch to Platform first tells that it can take
  /// an admin seat of the license, and either switch then asks once about the unsaved changes of any open form, which
  /// the switch closes. AppSessionListeners opens the new mode, or tells why the switch was refused.
  Future<void> _switchMode(BuildContext context) async {
    final to = switch (target) {
      SessionTarget.studio => SessionTarget.platform,
      SessionTarget.platform => SessionTarget.studio,
    };
    if (to == SessionTarget.platform && !await _confirmPlatformSeat(context)) return;
    if (!context.mounted) return;
    if (!await context.read<UnsavedChangesRegistry>().confirmLeavingAll(context)) return;
    if (!context.mounted) return;
    context.read<SessionTargetSwitchBloc>().add(SessionTargetSwitchRequested(to));
  }

  static Future<bool> _confirmPlatformSeat(BuildContext context) async {
    final l10n = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        parentContext: context,
        title: l10n.profile_switch_platform_title,
        message: l10n.profile_switch_platform_message,
        confirmText: l10n.profile_switch_confirm,
        cancelText: l10n.cancel,
      ),
    );
    return confirmed ?? false;
  }
}
