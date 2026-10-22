import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// Covers [child] with a barrier and a progress indicator while the sign-out the user started runs.
///
/// A sign-out waits for Studio's record for up to three seconds after the confirmed tap; the barrier tells the user it
/// is on its way and keeps a second tap from reaching the page.
class SignOutProgressBarrier extends StatelessWidget {
  const SignOutProgressBarrier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        BlocBuilder<SignOutBloc, SignOutState>(
          builder: (context, state) => switch (state) {
            SignOutInProgress() => Positioned.fill(
              child: Stack(
                children: [
                  ModalBarrier(dismissible: false, color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32)),
                  Center(
                    child: CircularProgressIndicator(
                      key: signOutProgressIndicatorKey,
                      semanticsLabel: S.of(context).loading,
                    ),
                  ),
                ],
              ),
            ),
            SignOutInitial() || SignOutDone() => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}
