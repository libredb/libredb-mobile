import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_unreachable_page.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// Shows [StudioUnreachablePage] over [child] while Studio does not answer its liveness check, and [child] otherwise,
/// also before the first answer arrives.
///
/// [child] stays mounted under the page, offstage and without tickers, focus or semantics, so the open pages keep
/// their state, unsaved input included, and show again as they were once Studio answers.
/// `App` places it beside `LifecycleGate` in the `MaterialApp` builder, around the session restore and the router, so
/// the page has no Navigator above it. It tells
/// [StudioStatusBloc] when the app goes to the background and comes back; the bloc decides whether to check again.
class StudioStatusGate extends StatefulWidget {
  const StudioStatusGate({super.key, required this.child});

  final Widget child;

  @override
  State<StudioStatusGate> createState() => _StudioStatusGateState();
}

class _StudioStatusGateState extends State<StudioStatusGate> with WidgetsBindingObserver {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        context.read<StudioStatusBloc>().add(const StudioAppPaused());
      case AppLifecycleState.resumed:
        context.read<StudioStatusBloc>().add(const StudioAppResumed());
      case AppLifecycleState.detached || AppLifecycleState.inactive || AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudioStatusBloc, StudioStatusState>(
      builder: (context, state) {
        final unreachable = switch (state) {
          StudioUnreachable(:final error, :final retrying) => StudioUnreachablePage(
            host: _hostOf(context.read<AppConfig>().apiBaseUrl),
            error: error,
            retrying: retrying,
          ),
          StudioStatusUnknown() || StudioReachable() || StudioGovernanceUnavailable() => null,
        };
        final hidden = unreachable != null;
        // The child stays first in the stack in every state, so its element, and every page state under it, is kept.
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: hidden,
              child: TickerMode(
                enabled: !hidden,
                child: ExcludeFocus(
                  excluding: hidden,
                  child: ExcludeSemantics(excluding: hidden, child: widget.child),
                ),
              ),
            ),
            ?unreachable,
          ],
        );
      },
    );
  }

  /// The host of [apiBaseUrl], with the port when the address names one, or null when there is no usable address.
  static String? _hostOf(String? apiBaseUrl) {
    final uri = apiBaseUrl == null ? null : Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty) return null;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }
}
