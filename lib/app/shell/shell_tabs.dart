import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// One tab of a shell's navigation: the route it opens, its icon, and its label in the app language.
typedef ShellTab = ({String route, IconData icon, String Function(S) label});

/// The tabs of the shell of [target], in the order of [ApplicationRoutesConstants.tabsFor].
///
/// Studio's are Connections, Browse and SQL, as Studio's MobileNav has them; Platform's are Home and Connections.
List<ShellTab> shellTabsFor(SessionTarget target) => switch (target) {
  SessionTarget.studio => [
    (route: ApplicationRoutesConstants.connectionList, icon: Icons.storage_outlined, label: (l10n) => l10n.connections),
    (route: ApplicationRoutesConstants.browse, icon: Icons.table_chart_outlined, label: (l10n) => l10n.tab_browse),
    (route: ApplicationRoutesConstants.sql, icon: Icons.terminal, label: (l10n) => l10n.tab_sql),
  ],
  SessionTarget.platform => [
    (route: ApplicationRoutesConstants.platformHome, icon: Icons.home_outlined, label: (l10n) => l10n.home),
    (
      route: ApplicationRoutesConstants.platformConnections,
      icon: Icons.storage_outlined,
      label: (l10n) => l10n.connections,
    ),
  ],
};
