import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/shell/shell_tabs.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:go_router/go_router.dart';

/// The tabs of the shell in a bottom navigation bar: Studio's Connections, Browse and SQL, as Studio's MobileNav has
/// them, or Platform's Home and Connections.
class BottomNavWidget extends StatelessWidget {
  /// The tabs of the shell, from [shellTabsFor].
  final List<ShellTab> tabs;

  /// The route of the tab of [tabs] that is open.
  final String activeTab;

  const BottomNavWidget({super.key, required this.tabs, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return NavigationBar(
      selectedIndex: _indexOf(tabs, activeTab),
      onDestinationSelected: (index) => context.go(tabs[index].route),
      destinations: [for (final tab in tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.label(l10n))],
    );
  }
}

/// The same tabs as [BottomNavWidget] in a rail at the side, for a screen too short for a bottom bar, such as a phone
/// held sideways.
class SideNavWidget extends StatelessWidget {
  /// The tabs of the shell, from [shellTabsFor].
  final List<ShellTab> tabs;

  /// The route of the tab of [tabs] that is open.
  final String activeTab;

  const SideNavWidget({super.key, required this.tabs, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    // The keyboard leaves the rail less height than its tabs need, so it then scrolls rather than overflow.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: _indexOf(tabs, activeTab),
              onDestinationSelected: (index) => context.go(tabs[index].route),
              labelType: NavigationRailLabelType.all,
              groupAlignment: 0,
              destinations: [
                for (final tab in tabs) NavigationRailDestination(icon: Icon(tab.icon), label: Text(tab.label(l10n))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _indexOf(List<ShellTab> tabs, String route) => tabs.indexWhere((tab) => tab.route == route);
