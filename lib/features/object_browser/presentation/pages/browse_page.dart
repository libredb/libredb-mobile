import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';

/// The root of the Browse tab: the objects of the open connection.
///
/// No connection can be opened yet, so the tab asks the user to pick one first.
class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PickConnectionFirst(
      icon: Icons.table_chart_outlined,
      onOpenConnections: () => context.go(ApplicationRoutesConstants.connectionList),
    );
  }
}
