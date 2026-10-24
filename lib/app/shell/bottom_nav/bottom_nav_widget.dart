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
    return NavigationBar(
      selectedIndex: ApplicationRoutesConstants.tabs.indexOf(activeTab),
      onDestinationSelected: (index) => _open(context, index),
      destinations: [
        for (final tab in _tabs(S.of(context))) NavigationDestination(icon: Icon(tab.icon), label: tab.label),
      ],
    );
  }
}

/// The same tabs as [BottomNavWidget] in a rail at the side, for a screen too short for a bottom bar, such as a phone
/// held sideways.
class SideNavWidget extends StatelessWidget {
  /// The tab of [ApplicationRoutesConstants.tabs] that is open.
  final String activeTab;

  const SideNavWidget({super.key, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: ApplicationRoutesConstants.tabs.indexOf(activeTab),
      onDestinationSelected: (index) => _open(context, index),
      labelType: NavigationRailLabelType.all,
      groupAlignment: 0,
      destinations: [
        for (final tab in _tabs(S.of(context))) NavigationRailDestination(icon: Icon(tab.icon), label: Text(tab.label)),
      ],
    );
  }
}

/// The icon and the label of each tab, in the order of [ApplicationRoutesConstants.tabs].
List<({IconData icon, String label})> _tabs(S l10n) => [
  (icon: Icons.storage_outlined, label: l10n.connections),
  (icon: Icons.table_chart_outlined, label: l10n.tab_browse),
  (icon: Icons.terminal, label: l10n.tab_sql),
];

void _open(BuildContext context, int index) => context.go(ApplicationRoutesConstants.tabs[index]);
