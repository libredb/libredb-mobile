import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_status_gate.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_status_gate.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// The liveness gates around [child], each covering only the sessions that call its server.
///
/// In a build without a Platform target, [StudioStatusGate] covers the restore, the login page and a Studio session,
/// and passes a signed-in Platform session through, which such a build never restores; Platform is never asked.
///
/// In a build with a Platform target, [StudioStatusGate] covers only a Studio session and [PlatformStatusGate] only a
/// Platform session; the restore, which calls neither server, and the login page, whose entries each say when their
/// own server does not answer, are covered by neither. Platform's first liveness check is sent here, once, when the
/// login page or a Platform session first needs it.
///
/// The gates are feature widgets, which cannot read [SessionCubit], so the app layer decides here. A session change
/// rebuilds only the gates' pass-through flags, so [child] keeps its place in the tree and open pages keep their state.
class AppStatusGate extends StatelessWidget {
  const AppStatusGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (context.read<AppConfig>().platform) {
      PlatformNotConfigured() => BlocSelector<SessionCubit, SessionState, bool>(
        selector: (state) => switch (state) {
          SessionAuthenticated(target: SessionTarget.platform) => true,
          SessionAuthenticated(target: SessionTarget.studio) || SessionUnknown() || SessionUnauthenticated() => false,
        },
        builder: (context, passThrough) => StudioStatusGate(passThrough: passThrough, child: child),
      ),
      PlatformConfigured() => _TargetGates(child: child),
    };
  }
}

/// The two gates of a build with a Platform target, and Platform's first liveness check.
class _TargetGates extends StatefulWidget {
  const _TargetGates({required this.child});

  final Widget child;

  @override
  State<_TargetGates> createState() => _TargetGatesState();
}

class _TargetGatesState extends State<_TargetGates> {
  /// Whether Platform's first liveness check was sent.
  bool _platformAsked = false;

  @override
  void initState() {
    super.initState();
    _askPlatformWhenNeeded(context.read<SessionCubit>().state);
  }

  /// Sends Platform's first liveness check when [session] is the login page or a Platform session, once per run.
  void _askPlatformWhenNeeded(SessionState session) {
    if (_platformAsked) return;
    final needsPlatform = switch (session) {
      SessionUnauthenticated() || SessionAuthenticated(target: SessionTarget.platform) => true,
      SessionUnknown() || SessionAuthenticated(target: SessionTarget.studio) => false,
    };
    if (!needsPlatform) return;
    _platformAsked = true;
    context.read<PlatformStatusBloc>().add(const PlatformLivenessCheckRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionCubit, SessionState>(
      listener: (context, session) => _askPlatformWhenNeeded(session),
      child: BlocSelector<SessionCubit, SessionState, SessionTarget?>(
        selector: (state) => switch (state) {
          SessionAuthenticated(:final target) => target,
          SessionUnknown() || SessionUnauthenticated() => null,
        },
        builder: (context, target) => StudioStatusGate(
          passThrough: target != SessionTarget.studio,
          child: PlatformStatusGate(passThrough: target != SessionTarget.platform, child: widget.child),
        ),
      ),
    );
  }
}
