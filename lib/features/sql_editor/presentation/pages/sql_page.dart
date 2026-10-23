import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/pages/editor_page.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';

/// The root of the SQL tab, which follows the active connection as the Browse tab does: the editor of the open
/// connection, built afresh when another one opens, or, without an open connection, the way to pick one first.
class SqlPage extends StatelessWidget {
  const SqlPage({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionId = context.select<ActiveConnectionCubit, String?>((cubit) => cubit.state.connection?.id);
    if (connectionId == null) {
      return PickConnectionFirst(
        icon: Icons.terminal,
        onOpenConnections: () => context.go(ApplicationRoutesConstants.connectionList),
      );
    }
    return EditorPage(key: ValueKey(connectionId), connectionId: connectionId);
  }
}
