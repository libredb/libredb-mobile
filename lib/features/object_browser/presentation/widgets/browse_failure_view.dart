import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

/// The one failure view of every Browse page: Studio's error in `StudioErrorBanner`, with the page's [onRetry].
///
/// `studio.connection_not_available` means Studio no longer offers [connectionId], so the view also hands it to the
/// active connection's vanish flow, which names the connection and closes the pages that showed it when it is the
/// active one.
class BrowseFailureView extends StatefulWidget {
  const BrowseFailureView({super.key, required this.connectionId, required this.error, this.onRetry});

  final String connectionId;
  final AppError error;
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

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
    child: StudioErrorBanner(error: widget.error, onRetry: widget.onRetry),
  );
}
