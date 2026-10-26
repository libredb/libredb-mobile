import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/account_refusal_status.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:libredb_mobile/shared/widgets/studio_unreachable_status.dart';

/// The one failure view of every Browse page: Studio's error in `StudioErrorBanner`, with the page's [onRetry].
///
/// `studio.connection_not_available` means Studio no longer offers [connectionId], so the view also hands it to the
/// active connection's vanish flow, which names the connection and closes the pages that showed it when it is the
/// active one.
///
/// A request the offline device never sent (`network.offline`) calls [onRetry] by itself once the device is back
/// online, as the connection list does; any other failure waits for the user's Retry.
///
/// Studio accepting the signed-in account again after the shell's refusal page covered the page, or answering again
/// after its unreachable page covered it, calls [onRetry] once too, unless it [runsStatement]: a statement is never run
/// again on its own.
class BrowseFailureView extends StatefulWidget {
  const BrowseFailureView({
    super.key,
    required this.connectionId,
    required this.error,
    required this.runsStatement,
    this.onRetry,
  });

  final String connectionId;
  final AppError error;

  /// Whether [onRetry] runs a statement, such as the rows of an object, rather than a lookup of Studio's metadata.
  final bool runsStatement;
  final VoidCallback? onRetry;

  @override
  State<BrowseFailureView> createState() => _BrowseFailureViewState();
}

class _BrowseFailureViewState extends State<BrowseFailureView> {
  @override
  void initState() {
    super.initState();
    _reportVanished();
  }

  @override
  void didUpdateWidget(BrowseFailureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error != widget.error || oldWidget.connectionId != widget.connectionId) _reportVanished();
  }

  void _reportVanished() {
    if (widget.error.code != AppErrorCode.studioConnectionNotAvailable.key) return;
    final connectionId = widget.connectionId;
    // The vanish flow navigates, which must not happen while this view builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ActiveConnectionCubit>().reportUnavailable(connectionId);
    });
  }

  /// Whether coming back online cures the failure: a request the offline device never sent, so sending it again runs
  /// nothing twice. Any other network error may have reached Studio, and a statement is never run again on its own.
  bool get _curedByConnection => widget.error.code == AppErrorCode.networkOffline.key;

  @override
  Widget build(BuildContext context) {
    final banner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: StudioErrorBanner(error: widget.error, onRetry: widget.onRetry),
    );
    final onRetry = widget.onRetry;
    if (onRetry == null) return banner;
    final view = _curedByConnection ? OnReconnect(onReconnect: onRetry, child: banner) : banner;
    if (widget.runsStatement) return view;
    return OnAccountAccepted(
      onAccepted: onRetry,
      child: OnStudioReachable(onReachable: onRetry, child: view),
    );
  }
}
