import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:go_router/go_router.dart';

/// The tabs of the shell, as Studio's MobileNav has them: Connections, Browse and SQL.
class BottomNavWidget extends StatelessWidget {
  /// The tab of [ApplicationRoutesConstants.tabs] that is open.
  final String activeTab;

  const BottomNavWidget({super.key, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return NavigationBar(
      selectedIndex: ApplicationRoutesConstants.tabs.indexOf(activeTab),
      onDestinationSelected: (index) => context.go(ApplicationRoutesConstants.tabs[index]),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.storage_outlined), label: l10n.connections),
        NavigationDestination(icon: const Icon(Icons.table_chart_outlined), label: l10n.tab_browse),
        NavigationDestination(icon: const Icon(Icons.terminal), label: l10n.tab_sql),
      ],
    );
  }
}
