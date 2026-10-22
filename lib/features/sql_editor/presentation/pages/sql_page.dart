import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';

/// The root of the SQL tab: the editor of the open connection.
///
/// No connection can be opened yet, so the tab asks the user to pick one first.
class SqlPage extends StatelessWidget {
  const SqlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PickConnectionFirst(
      icon: Icons.terminal,
      onOpenConnections: () => context.go(ApplicationRoutesConstants.connectionList),
    );
  }
}
