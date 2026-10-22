import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/shell/bottom_nav/bottom_nav_widget.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// The frame around every signed-in page: the top bar with the page title above it and the bottom navigation bar below
/// it, at every screen width.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({super.key, required this.child, required this.activeRoute});

  final Widget child;
  final String activeRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The Scaffold already keeps the body above the bottom navigation bar, which keeps clear of the bottom inset.
      body: SafeArea(
        child: Column(
          children: [
            TopBarWidget(title: _routeToTitle(activeRoute, S.of(context))),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavWidget(activeRoute: activeRoute),
    );
  }

  String _routeToTitle(String route, S l10n) {
    final segments = route.split('/').where((value) => value.isNotEmpty).toList();
    if (segments.isEmpty) return l10n.connections;
    final segment = segments.first;
    return switch (segment) {
      'connections' => l10n.connections,
      'settings' => l10n.settings,
      _ => segment.replaceFirst(segment[0], segment[0].toUpperCase()),
    };
  }
}
