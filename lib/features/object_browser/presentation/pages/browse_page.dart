import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/container_level_page.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';

/// The root of the Browse tab and the one Browse page that follows the active connection: its first level in place,
/// its containers or, on an engine with no container level, its kinds.
///
/// Without an open connection the tab asks the user to pick one first. Another connection opening builds its first
/// level afresh, as a first entry; the shell has already returned the Browse stack here.
class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionId = context.select<ActiveConnectionCubit, String?>((cubit) => cubit.state.connection?.id);
    if (connectionId == null) {
      return PickConnectionFirst(
        icon: Icons.table_chart_outlined,
        onOpenConnections: () => context.go(ApplicationRoutesConstants.connectionList),
      );
    }
    return ContainerLevelPage(key: ValueKey(connectionId), connectionId: connectionId);
  }
}
