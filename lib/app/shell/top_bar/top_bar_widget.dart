import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/widgets/confirmation_dialog_widget.dart';
import 'package:go_router/go_router.dart';

/// Top bar — h-12, border-b, px-4, flex items-center.
class TopBarWidget extends StatelessWidget {
  final String title;

  const TopBarWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 48, // h-12
      padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Takes the width that the user menu leaves, and is shortened when that is too little.
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildUserMenu(context),
        ],
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      icon: Icon(Icons.account_circle_outlined, color: cs.onSurfaceVariant),
      onSelected: (value) => _onMenuSelected(context, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'settings',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(S.of(context).settings, style: tt.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'logout',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.logout, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(S.of(context).logout, style: tt.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'settings':
        context.go(ApplicationRoutesConstants.settings);
        break;
      case 'logout':
        _handleLogout(context);
        break;
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
