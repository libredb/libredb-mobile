import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/bottom_nav/bottom_nav_widget.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// The frame around every signed-in page, at every screen width: the one top bar with the page title above it, and
/// below it the bottom navigation bar on a tab, or a back arrow in the top bar on any other page, such as the settings.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({super.key, required this.child, required this.activeRoute});

  final Widget child;
  final String activeRoute;

  @override
  Widget build(BuildContext context) {
    final tab = _tabOf(activeRoute);
    return Scaffold(
      // The Scaffold already keeps the body above the bottom navigation bar, which keeps clear of the bottom inset.
      body: SafeArea(
        child: Column(
          children: [
            TopBarWidget(
              title: _routeToTitle(activeRoute, S.of(context)),
              onBack: tab == null ? () => _back(context) : null,
            ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: tab == null ? null : BottomNavWidget(activeTab: tab),
    );
  }

  /// The tab [route] is in, or null for a page that is no tab.
  static String? _tabOf(String route) {
    for (final tab in ApplicationRoutesConstants.tabs) {
      if (route == tab || route.startsWith('$tab/')) return tab;
    }
    return null;
  }

  /// Returns to the page under this one, or to the connection list for a page opened by a link with nothing under it.
  static void _back(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(ApplicationRoutesConstants.home);
    }
  }

  String _routeToTitle(String route, S l10n) {
    final segments = route.split('/').where((value) => value.isNotEmpty).toList();
    if (segments.isEmpty) return l10n.connections;
    final segment = segments.first;
    return switch (segment) {
      'connections' => l10n.connections,
      'browse' => l10n.tab_browse,
      'sql' => l10n.tab_sql,
      'settings' => l10n.settings,
      _ => segment.replaceFirst(segment[0], segment[0].toUpperCase()),
    };
  }
}
