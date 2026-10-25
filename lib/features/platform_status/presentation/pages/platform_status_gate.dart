import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_state.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_unreachable_page.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// Shows [PlatformUnreachablePage] over [child] while Platform does not answer its liveness check, and [child]
/// otherwise, also before the first answer arrives: the mirror of `StudioStatusGate`.
///
/// [child] stays mounted under the page, offstage and without tickers, focus or semantics, so the open pages keep
/// their state, unsaved input included, and show again as they were once Platform answers. It tells
/// [PlatformStatusBloc] when the app goes to the background and comes back; the bloc decides whether to check again.
///
/// With [passThrough] it shows [child] whatever Platform answers, keeping it in the same place in the tree: anything
/// but a signed-in Platform session, which the app layer decides, since a feature cannot read the session.
class PlatformStatusGate extends StatefulWidget {
  const PlatformStatusGate({super.key, this.passThrough = false, required this.child});

  /// Whether [child] is shown even while Platform does not answer.
  final bool passThrough;

  final Widget child;

  @override
  State<PlatformStatusGate> createState() => _PlatformStatusGateState();
}

class _PlatformStatusGateState extends State<PlatformStatusGate> with WidgetsBindingObserver {
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
        context.read<PlatformStatusBloc>().add(const PlatformAppPaused());
      case AppLifecycleState.resumed:
        context.read<PlatformStatusBloc>().add(const PlatformAppResumed());
      case AppLifecycleState.detached || AppLifecycleState.inactive || AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlatformStatusBloc, PlatformStatusState>(
      builder: (context, state) {
        final unreachable = switch (state) {
          PlatformUnreachable() when widget.passThrough => null,
          PlatformUnreachable(:final error, :final retrying) => PlatformUnreachablePage(
            host: _hostOf(context.read<AppConfig>().platform),
            error: error,
            retrying: retrying,
          ),
          PlatformStatusUnknown() || PlatformReachable() => null,
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

  /// The host of Platform's base URL, with the port when the address names one, or null when there is no usable
  /// address.
  static String? _hostOf(PlatformTargetConfig platform) {
    final baseUrl = switch (platform) {
      PlatformConfigured(:final baseUrl) => baseUrl,
      PlatformNotConfigured() => null,
    };
    final uri = baseUrl == null ? null : Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return null;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }
}
