import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/bottom_nav/bottom_nav_widget.dart';
import 'package:libredb_mobile/app/shell/top_bar/active_connection_title.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// The frame around every signed-in page, at every screen width: the one top bar with the page title above it, and
/// below it the bottom navigation bar on a tab, or a back arrow in the top bar on any other page, such as the settings.
/// A page under the Browse root keeps the bottom navigation bar and has the back arrow too. On every Browse and SQL
/// location the title is the active connection, which opens the connection switcher.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({super.key, required this.child, required this.activeRoute});

  final Widget child;
  final String activeRoute;

  @override
  Widget build(BuildContext context) {
    final tab = _tabOf(activeRoute);
    final title = _routeToTitle(activeRoute, S.of(context));
    return Scaffold(
      // The Scaffold already keeps the body above the bottom navigation bar, which keeps clear of the bottom inset.
      body: SafeArea(
        child: Column(
          children: [
            TopBarWidget(
              title: title,
              onBack: tab == null
                  ? () => _back(context)
                  : _inBrowseStack(activeRoute)
                  ? () => _backInBrowse(context)
                  : null,
              // The Browse and SQL tabs work on the active connection, so their title names it.
              titleWidget: _worksOnActiveConnection(tab) ? ActiveConnectionTitle(fallback: title) : null,
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

  /// Whether [tab] works on the active connection, so its top bar names it.
  static bool _worksOnActiveConnection(String? tab) =>
      tab == ApplicationRoutesConstants.browse || tab == ApplicationRoutesConstants.sql;

  /// Whether [route] is a page under the Browse root, which keeps the tab's bottom navigation bar and has a back arrow,
  /// since iOS has no system back.
  static bool _inBrowseStack(String route) => route.startsWith('${ApplicationRoutesConstants.browse}/');

  /// Returns to the Browse page under this one, or to the Browse root for a page opened by a link with nothing under
  /// it.
  static void _backInBrowse(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(ApplicationRoutesConstants.browse);
    }
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
