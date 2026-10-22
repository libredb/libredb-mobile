import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_banner.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/account_refusal/studio_account_refusal_page.dart';
import 'package:libredb_mobile/app/shell/governance_status_scope.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/app/shell/sign_out_flow.dart';
import 'package:libredb_mobile/app/shell/sign_out_progress_barrier.dart';
import 'package:libredb_mobile/app/dev_console/dev_console_overlay.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    // Asks Studio who the user is and what it allows once the signed-in shell opens; the sign-out clears both, so the
    // next user to sign in is asked about again.
    final identity = context.read<StudioIdentityCubit>();
    if (identity.state is StudioIdentityInitial) identity.load();
    final policy = context.read<ConnectionPolicyCubit>();
    if (policy.state is ConnectionPolicyInitial) policy.load();
  }

  /// [screen], covered by the refusal page while Studio refuses the signed-in account, decided here only and never by
  /// a screen. The screen stays mounted under the page, hidden and with its tickers off, because it holds the shell's
  /// navigator; Studio accepting `/api/auth/me` again on Retry uncovers it.
  Widget _accountRefusalOr(Widget screen) {
    return BlocListener<StudioIdentityCubit, StudioIdentityState>(
      listenWhen: (previous, current) => current is StudioIdentityLoaded,
      listener: (context, state) => context.read<StudioAccountRefusalCubit>().clear(),
      child: BlocBuilder<StudioAccountRefusalCubit, StudioAccountRefusalState>(
        builder: (context, refusal) {
          final refused = refusal is StudioAccountRefused;
          return Stack(
            children: [
              Offstage(
                offstage: refused,
                child: TickerMode(enabled: !refused, child: screen),
              ),
              switch (refusal) {
                StudioAccountAccepted() => const SizedBox.shrink(),
                StudioAccountRefused(:final errorCode) => BlocSelector<StudioIdentityCubit, StudioIdentityState, bool>(
                  selector: (state) => state is StudioIdentityLoading,
                  builder: (context, retrying) => StudioAccountRefusalPage(
                    errorCode: errorCode,
                    retrying: retrying,
                    onRetry: () => context.read<StudioIdentityCubit>().load(),
                    onSignOut: () => confirmAndSignOut(context),
                  ),
                ),
              },
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DevConsoleShortcut(
      child: SignOutProgressBarrier(
        child: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              // The offline banner already pads itself below the status bar, so the shell must not add that inset again.
              child: BlocSelector<ConnectivityCubit, ConnectivityState, bool>(
                selector: (state) => state.isOffline,
                builder: (context, isOffline) => MediaQuery.removePadding(
                  context: context,
                  removeTop: isOffline,
                  child: _accountRefusalOr(
                    ResponsiveScaffold(
                      activeRoute: widget.state.uri.path,
                      child: GovernanceStatusScope(child: widget.child),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
