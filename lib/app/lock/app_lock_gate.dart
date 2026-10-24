import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/shell/sign_out_flow.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/app_lock/presentation/pages/app_lock_screen.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// Puts the lock screen over [child], the app's router and everything above it in the `MaterialApp` builder, while
/// [AppLockBloc] covers the app.
///
/// [child] stays mounted under it, so the pages and what they hold, an editor's text and a shown result, are as they
/// were once the lock opens. While covered, [child] is offstage: not painted, not reachable by touch, left out of the
/// semantics tree so a screen reader reads only the lock screen, and with its tickers off, so its screen capture
/// guards give their leases back.
///
/// The system back does nothing while the lock covers the app: the gate is mounted before the router, so it sees the
/// back first and keeps the router from popping a page under the lock.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.router, required this.child});

  /// The app's router, which the lock screen's sign-out sends to the login page; the gate sits above the router, so
  /// its context finds none.
  final GoRouter router;

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Takes the system back while the lock covers the app, so nothing under it pops.
  @override
  Future<bool> didPopRoute() async => context.read<AppLockBloc>().state.coversApp;

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockBloc>().state;
    final signedIn = context.select<SessionCubit, bool>((session) => session.state is SessionAuthenticated);
    final signingOut = context.select<SignOutBloc, bool>((signOut) => signOut.state is SignOutInProgress);
    final covered = lock.coversApp;
    // The settings are still being read after a restore: nothing signed in shows until the lock has decided.
    final deciding = lock is AppLockStarting && signedIn;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: covered || deciding,
          child: TickerMode(enabled: !covered && !deciding, child: widget.child),
        ),
        if (covered)
          AppLockScreen(
            signingOut: signingOut,
            onSignOut: () => signOutThenOpenLogin(context.read<SignOutBloc>(), widget.router, isMounted: () => mounted),
          )
        else if (deciding)
          const _Deciding(),
      ],
    );
  }
}

/// The theme background with a spinner, as the restore shows, while the lock reads its settings.
class _Deciding extends StatelessWidget {
  const _Deciding();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: appLockRestoreKey,
      color: Theme.of(context).colorScheme.surface,
      child: Center(child: CircularProgressIndicator(semanticsLabel: S.of(context).loading)),
    );
  }
}
