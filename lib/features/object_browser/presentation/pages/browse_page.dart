import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';

/// The root of the Browse tab: the objects of the open connection.
///
/// Without an open connection the tab asks the user to pick one first.
/// The objects themselves are not shown yet, so with an open connection, whose name the shell's top bar shows, the
/// tab says only that browsing is not available yet.
class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final open = context.select<ActiveConnectionCubit, bool>((cubit) => cubit.state.connection != null);
    if (open) {
      return AppEmptyState(icon: Icons.table_chart_outlined, title: S.of(context).browse_not_available_yet);
    }
    return PickConnectionFirst(
      icon: Icons.table_chart_outlined,
      onOpenConnections: () => context.go(ApplicationRoutesConstants.connectionList),
    );
  }
}
