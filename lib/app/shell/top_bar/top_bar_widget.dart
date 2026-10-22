import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/widgets/confirmation_dialog_widget.dart';
import 'package:go_router/go_router.dart';

/// The one top bar of the shell: a back arrow on a page that is no tab, the page title, and the avatar that opens the
/// profile sheet.
class TopBarWidget extends StatelessWidget {
  final String title;

  /// Returns from a page that is no tab; null on a tab, which has no back arrow.
  final VoidCallback? onBack;

  const TopBarWidget({super.key, required this.title, this.onBack});

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
            child: Text(
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
    final action = await ProfileSheet.show(context);
    if (action == null || !context.mounted) return;
    switch (action) {
      case ProfileSheetAction.settings:
        final router = GoRouter.of(context);
        // Stacks on the open tab, so the back arrow returns to it; on the settings it stays.
        if (router.state.uri.path != ApplicationRoutesConstants.settings) {
          router.push(ApplicationRoutesConstants.settings);
        }
      case ProfileSheetAction.signOut:
        await _handleLogout(context);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await ConfirmationDialog.show(context: context, type: DialogType.logout) ?? false;
    if (!shouldLogout || !context.mounted) return;
    // AWAIT the end of the sign-out before navigating: navigating
    // immediately would race the async logout work and (with the
    // router's "authenticated user on public route → home" rule)
    // momentarily bounce back to home until SessionCubit catches up.
    final signOutBloc = context.read<SignOutBloc>();
    signOutBloc.add(const SignOutRequested());
    await signOutBloc.stream.firstWhere((state) => state is SignOutDone);
    if (!context.mounted) return;
    context.go(ApplicationRoutesConstants.login);
    // A logout that cannot remove all stored data signs out too, and
    // AppSessionListeners tells the user so.
  }
}
