import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_status_gate.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// [StudioStatusGate] around [child], passing a signed-in Platform session through: it calls Platform, not Studio, so
/// the Studio unreachable page does not cover it. The restore, the login page and a Studio session are covered as
/// before.
///
/// The gate is a feature widget, which cannot read [SessionCubit], so the app layer decides here. A session change
/// rebuilds only the gate's [StudioStatusGate.passThrough], so [child] keeps its place in the tree.
class AppStudioStatusGate extends StatelessWidget {
  const AppStudioStatusGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SessionCubit, SessionState, bool>(
      selector: (state) => switch (state) {
        SessionAuthenticated(target: SessionTarget.platform) => true,
        SessionAuthenticated(target: SessionTarget.studio) || SessionUnknown() || SessionUnauthenticated() => false,
      },
      builder: (context, passThrough) => StudioStatusGate(passThrough: passThrough, child: child),
    );
  }
}
