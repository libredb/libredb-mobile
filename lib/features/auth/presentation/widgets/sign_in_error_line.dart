import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// Which error the sign-in surface is showing, or null when it is showing none.
///
/// A top-level function rather than a method, because two places have to agree about it: the line below, and the
/// auto-redirect gate, which must not send the user to the provider while an error is on screen. When the answer
/// lived in the page's `State` the two read the same method by luck; here they read the same function by
/// construction, and it can be checked without pumping a widget (#379).
///
/// [tapped] is whether the user has pressed a sign-in entry in this session: a startup error belongs to the build
/// the user arrived on, so it stops being theirs once they have tried.
AppErrorCode? signInErrorCode({
  required AuthMode mode,
  required LoginState state,
  required AppErrorCode? startupError,
  required bool tapped,
}) => switch (state) {
  LoginErrorState(:final errorCode) => errorCode,
  LoginLoadingState() || LoginLoadedState() => null,
  LoginInitialState() =>
    (tapped ? null : startupError) ?? (mode is OidcMisconfiguredAuthMode ? AppErrorCode.authOidcConfig : null),
};

/// The sign-in error, as the page shows it.
class SignInErrorLine extends StatelessWidget {
  const SignInErrorLine({super.key, required this.mode, required this.startupError, required this.tapped});

  final AuthMode mode;
  final AppErrorCode? startupError;
  final bool tapped;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) =>
          switch (signInErrorCode(mode: mode, state: state, startupError: startupError, tapped: tapped)) {
            // A live region, because the line appears without a navigation or a focus change: without it VoiceOver
            // and TalkBack never speak the error, and on a misconfigured build this page shows nothing else.
            final errorCode? => Semantics(
              liveRegion: true,
              child: Center(
                child: Text(
                  errorCode.resolve(context),
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            null => const SizedBox.shrink(),
          },
    );
  }
}
