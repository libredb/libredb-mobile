import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/bottom_nav/bottom_nav_widget.dart';
import 'package:libredb_mobile/app/shell/shell_tabs.dart';
import 'package:libredb_mobile/app/shell/top_bar/active_connection_title.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_breakpoints.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// The frame around every signed-in page, at every screen width: the one top bar with the page title above it, and
/// below it the bottom navigation bar on a tab, or a back arrow in the top bar on any other page, such as the settings.
/// On a compact height, such as a phone held sideways, a tab page has its tabs in a rail at the side instead, which
/// leaves the page the height a bottom bar takes.
/// A page under a tab root, such as one under the Browse root, keeps the bottom navigation bar and has the back arrow
/// too. On every Browse and SQL location the title is the active connection, which opens the connection switcher.
///
/// The tabs, the home and the titles are those of [target]'s shell: Studio's, or Platform's under `/platform`.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({super.key, required this.target, required this.child, required this.activeRoute});

  final SessionTarget target;
  final Widget child;
  final String activeRoute;

  @override
  Widget build(BuildContext context) {
    final tabs = shellTabsFor(target);
    final tab = _tabOf(activeRoute);
    final title = _routeToTitle(activeRoute, S.of(context));
    final rail = tab != null && AppBreakpoints.isCompactHeight(MediaQuery.sizeOf(context).height);
    return Scaffold(
      // The page keeps its place in the tree whether the tabs are at the bottom or at the side, so a rotation keeps
      // its state, such as a result's rows and scroll position.
      body: Row(
        children: [
          if (rail) ...[
            SafeArea(
              right: false,
              child: SideNavWidget(tabs: tabs, activeTab: tab),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            key: const ValueKey('shell-page'),
            // The Scaffold already keeps the body above the bottom navigation bar, which keeps clear of the bottom
            // inset; the rail keeps clear of the left one.
            child: SafeArea(
              left: !rail,
              child: Column(
                children: [
                  TopBarWidget(
                    target: target,
                    title: title,
                    onBack: tab == null
                        ? () => _back(context)
                        : _hasBackInTab(activeRoute, tab)
                        ? () => _backInTab(context, tab)
                        : null,
                    // The Browse and SQL tabs work on the active connection, so their title names it.
                    titleWidget: _worksOnActiveConnection(tab) ? ActiveConnectionTitle(fallback: title) : null,
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: tab == null || rail ? null : BottomNavWidget(tabs: tabs, activeTab: tab),
    );
  }

  /// The tab [route] is in, or null for a page that is no tab: the tab root that equals [route] or is a prefix of it
  /// followed by `/`. The Platform home is a prefix of every Platform route, so it matches only itself, and
  /// `/platform/settings` is no tab.
  String? _tabOf(String route) {
    for (final tab in ApplicationRoutesConstants.tabsFor(target)) {
      if (route == tab) return tab;
      if (tab != ApplicationRoutesConstants.platformHome && route.startsWith('$tab/')) return tab;
    }
    return null;
  }

  /// Whether [route], in [tab], has a back arrow while keeping the tab's bottom navigation bar: in Studio a page under
  /// the Browse root, as before Platform mode, and the access request pages under the connection list; in Platform any
  /// page under a tab root.
  bool _hasBackInTab(String route, String tab) => switch (target) {
    SessionTarget.studio =>
      route.startsWith('${ApplicationRoutesConstants.browse}/') ||
          route.startsWith('${ApplicationRoutesConstants.connectionList}/'),
    SessionTarget.platform => route != tab,
  };

  /// Whether [tab] works on the active connection, so its top bar names it. Only Studio's Browse and SQL tabs do.
  static bool _worksOnActiveConnection(String? tab) =>
      tab == ApplicationRoutesConstants.browse || tab == ApplicationRoutesConstants.sql;

  /// Returns to the page under this one in [tab], or to the root of [tab] for a page opened by a link with nothing
  /// under it. A page under a tab root keeps the tab's bottom navigation bar and has this back arrow, since iOS has no
  /// system back.
  static void _backInTab(BuildContext context, String tab) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(tab);
    }
  }

  /// Returns to the page under this one, or to the home of [target] for a page opened by a link with nothing under it.
  void _back(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(ApplicationRoutesConstants.homeFor(target));
    }
  }

  String _routeToTitle(String route, S l10n) => switch (target) {
    SessionTarget.studio => _studioTitle(route, l10n),
    SessionTarget.platform => _platformTitle(route, l10n),
  };

  /// The title of a Platform route, read after the `/platform` prefix.
  static String _platformTitle(String route, S l10n) {
    final segments = route.split('/').where((value) => value.isNotEmpty).skip(1).toList();
    if (segments.isEmpty) return l10n.home;
    final segment = segments.first;
    return switch (segment) {
      'connections' => l10n.connections,
      'audit' => l10n.platform_audit_tab,
      'settings' => l10n.settings,
      _ => segment.replaceFirst(segment[0], segment[0].toUpperCase()),
    };
  }

  static String _studioTitle(String route, S l10n) {
    final segments = route.split('/').where((value) => value.isNotEmpty).toList();
    if (segments.isEmpty) return l10n.connections;
    final segment = segments.first;
    return switch (segment) {
      'connections' when route == ApplicationRoutesConstants.accessRequests => l10n.access_requests_title,
      'connections' when route == ApplicationRoutesConstants.accessRequestNew => l10n.access_requests_new_title,
      'connections' => l10n.connections,
      'browse' => l10n.tab_browse,
      'sql' => l10n.tab_sql,
      'settings' => l10n.settings,
      _ => segment.replaceFirst(segment[0], segment[0].toUpperCase()),
    };
  }
}
