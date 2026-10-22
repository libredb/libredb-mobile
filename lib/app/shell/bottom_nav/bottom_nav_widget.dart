import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:go_router/go_router.dart';

/// Mobile bottom navigation bar.
class BottomNavWidget extends StatelessWidget {
  final String activeRoute;

  const BottomNavWidget({super.key, required this.activeRoute});

  int get _currentIndex {
    if (activeRoute == ApplicationRoutesConstants.settings) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.storage_outlined), label: S.of(context).connections),
        NavigationDestination(icon: const Icon(Icons.settings_outlined), label: S.of(context).settings),
      ],
    );
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(ApplicationRoutesConstants.connectionList);
        break;
      case 1:
        context.go(ApplicationRoutesConstants.settings);
        break;
    }
  }
}
