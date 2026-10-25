import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_banner.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/dev_console/dev_console_overlay.dart';
import 'package:libredb_mobile/app/session/platform_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/account_refusal/studio_account_refusal_page.dart';
import 'package:libredb_mobile/app/shell/app_platform_identity_scope.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/app/shell/sign_out_flow.dart';
import 'package:libredb_mobile/app/shell/sign_out_progress_barrier.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/user_data/signed_in_account_scope.dart';
import 'package:libredb_mobile/shared/widgets/account_refusal_status.dart';

/// The shell of a Platform session, around every route under `/platform`: the frame of [ResponsiveScaffold] with
/// Platform's tabs, the offline banner, the sign-out barrier, and the refusal page while Platform refuses the admin.
///
/// It reads nothing of Studio and provides none of the Studio scopes, so no Studio request leaves a Platform session.
/// Its [SignedInAccountScope] names no subject, since Platform mode keeps no data of an account on the device.
class PlatformShell extends StatefulWidget {
  const PlatformShell({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  State<PlatformShell> createState() => _PlatformShellState();
}

class _PlatformShellState extends State<PlatformShell> {
  @override
  void initState() {
    super.initState();
    // A restored session asks Platform who the admin is once the shell opens; a sign-in has already filled the cubit,
    // and the sign-out clears it, so the next admin to sign in is asked about again.
    final identity = context.read<PlatformIdentityCubit>();
    if (identity.state is PlatformIdentityInitial) identity.load();
  }

  /// [screen], covered by the refusal page while Platform refuses the signed-in admin, decided here only and never by
  /// a screen. The screen stays mounted under the page, hidden and with its tickers off, because it holds the shell's
  /// navigator; Platform accepting `GET /api/v1/me` again on Retry uncovers it.
  Widget _accountRefusalOr(Widget screen) {
    return BlocListener<PlatformIdentityCubit, PlatformIdentityState>(
      listenWhen: (previous, current) => current is PlatformIdentityLoaded,
      listener: (context, state) => context.read<PlatformAccountRefusalCubit>().clear(),
      child: BlocBuilder<PlatformAccountRefusalCubit, PlatformAccountRefusalState>(
        builder: (context, refusal) {
          final refused = refusal is PlatformAccountRefused;
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
                PlatformAccountAccepted() => const SizedBox.shrink(),
                PlatformAccountRefused(:final errorCode) =>
                  BlocSelector<PlatformIdentityCubit, PlatformIdentityState, bool>(
                    selector: (state) => state is PlatformIdentityLoading,
                    builder: (context, retrying) => StudioAccountRefusalPage(
                      title: S.of(context).platform_account_refusal_title,
                      errorCode: errorCode,
                      retrying: retrying,
                      onRetry: () => context.read<PlatformIdentityCubit>().load(),
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
              // The offline banner already pads itself below the status bar, so the shell must not add that inset
              // again.
              child: BlocSelector<ConnectivityCubit, ConnectivityState, bool>(
                selector: (state) => state.isOffline,
                builder: (context, isOffline) => MediaQuery.removePadding(
                  context: context,
                  removeTop: isOffline,
                  child: _accountRefusalOr(
                    ResponsiveScaffold(
                      target: SessionTarget.platform,
                      activeRoute: widget.state.uri.path,
                      // The shell's context, which stays mounted until the login page opens.
                      child: SignedInAccountScope(
                        subject: null,
                        signOut: () => signOutAndOpenLogin(context),
                        reloadStoredData: _reloadStoredData,
                        child: AppPlatformIdentityScope(child: widget.child),
                      ),
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

  /// Platform mode keeps no data of an account, so "Remove my data" is hidden and nothing may ask to reload it.
  static void _reloadStoredData() =>
      throw StateError('Platform mode keeps no account data on the device, so there is nothing to reload');
}
