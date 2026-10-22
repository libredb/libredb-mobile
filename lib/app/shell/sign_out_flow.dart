import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/shared/widgets/confirmation_dialog_widget.dart';

/// The user's sign-out from the shell: asks for confirmation, signs out, then opens the login page.
///
/// The profile sheet and the refusal page both start it.
Future<void> confirmAndSignOut(BuildContext context) async {
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
