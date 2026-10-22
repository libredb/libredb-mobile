import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_banner.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/app/dev_console/dev_console_overlay.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DevConsoleShortcut(
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
                child: ResponsiveScaffold(activeRoute: state.uri.path, child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
