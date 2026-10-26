import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_banner.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/account_refusal/studio_account_refusal_page.dart';
import 'package:libredb_mobile/app/shell/app_statement_capture_scope.dart';
import 'package:libredb_mobile/app/shell/app_studio_role_scope.dart';
import 'package:libredb_mobile/app/shell/app_signed_in_account_scope.dart';
import 'package:libredb_mobile/app/shell/app_studio_subject_scope.dart';
import 'package:libredb_mobile/app/shell/governance_status_scope.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/app/shell/sign_out_flow.dart';
import 'package:libredb_mobile/app/shell/sign_out_progress_barrier.dart';
import 'package:libredb_mobile/app/dev_console/dev_console_overlay.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/account_refusal_status.dart';

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

  /// Asks Studio again who the user is and what it allows when either answer failed while Studio's unreachable page
  /// covered the shell, as on a restore while Studio is down, once a check finds Studio answering and the page
  /// uncovers the shell; an answer that loaded, or that is still awaited, is left as it is.
  void _reloadFailedOnStudioReachable(BuildContext context, StudioStatusState state) {
    final identity = context.read<StudioIdentityCubit>();
    if (identity.state is StudioIdentityFailure) identity.load();
    final policy = context.read<ConnectionPolicyCubit>();
    if (policy.state is ConnectionPolicyFailure) policy.load();
  }

  /// [screen], covered by the refusal page while Studio refuses the signed-in account, decided here only and never by
  /// a screen. The screen stays mounted under the page, hidden and with its tickers off, because it holds the shell's
  /// navigator; Studio accepting `/api/auth/me` again on Retry uncovers it, and [AccountRefusalStatus] tells the
  /// screen, so one that failed while hidden loads again.
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
                child: TickerMode(
                  enabled: !refused,
                  child: AccountRefusalStatus(isRefused: refused, child: screen),
                ),
              ),
              switch (refusal) {
                StudioAccountAccepted() => const SizedBox.shrink(),
                StudioAccountRefused(:final errorCode) => BlocSelector<StudioIdentityCubit, StudioIdentityState, bool>(
                  selector: (state) => state is StudioIdentityLoading,
                  builder: (context, retrying) => StudioAccountRefusalPage(
                    title: S.of(context).account_refusal_title,
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
    return MultiBlocListener(
      listeners: [
        // The shell is mounted for a Studio session only, which the unreachable page covers while Studio is down.
        BlocListener<StudioStatusBloc, StudioStatusState>(
          listenWhen: (previous, current) => previous is StudioUnreachable && current is! StudioUnreachable,
          listener: _reloadFailedOnStudioReachable,
        ),
        BlocListener<ActiveConnectionCubit, ActiveConnectionState>(
          listenWhen: (previous, current) => current is ActiveConnectionVanished,
          listener: (context, state) => _onVanished(context, (state as ActiveConnectionVanished).vanished),
        ),
        BlocListener<ActiveConnectionCubit, ActiveConnectionState>(
          listenWhen: (previous, current) =>
              current.connection != null && previous.connection?.id != current.connection!.id,
          listener: (context, state) => _onSwitched(context),
        ),
      ],
      child: DevConsoleShortcut(
        child: SignOutProgressBarrier(
          child: Column(
            children: [
              const ConnectivityBanner(),
              Expanded(
                // The offline banner already pads itself below the status bar, so the shell must not add that inset
                // again.
                child: BlocSelector<ConnectivityCubit, ConnectivityState, bool>(
                  selector: (state) => state.isOffline,
                  builder: (context, isOffline) => MediaQuery.removePadding(
                    context: context,
                    removeTop: isOffline,
                    child: _accountRefusalOr(
                      ResponsiveScaffold(
                        target: SessionTarget.studio,
                        activeRoute: widget.state.uri.path,
                        child: AppStudioRoleScope(
                          child: AppStudioSubjectScope(
                            child: AppSignedInAccountScope(
                              child: AppStatementCaptureScope(child: GovernanceStatusScope(child: widget.child)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Names the vanished connection, never with the reason, and closes the pages that showed it for the connection
  /// list.
  void _onVanished(BuildContext context, StudioConnection vanished) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.of(context).connection_vanished(vanished.name))));
    if (_worksOnActiveConnection(widget.state.uri.path)) context.go(ApplicationRoutesConstants.connectionList);
  }

  /// Returns the Browse stack to its root when another connection opens, so no page of the previous one stays, without
  /// changing the visible tab.
  void _onSwitched(BuildContext context) {
    if (widget.state.uri.path.startsWith('${ApplicationRoutesConstants.browse}/')) {
      context.go(ApplicationRoutesConstants.browse);
    }
  }

  /// Whether the page at [location] shows the active connection: the Browse and SQL tabs and every page under them.
  static bool _worksOnActiveConnection(String location) => [
    ApplicationRoutesConstants.browse,
    ApplicationRoutesConstants.sql,
  ].any((tab) => location == tab || location.startsWith('$tab/'));
}
