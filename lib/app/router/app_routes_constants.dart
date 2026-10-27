import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/shared/models/editor_open_request.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

/// Routes for the application
///
/// This class contains all the routes used in the application.
class ApplicationRoutesConstants {
  /// The root of the app, which opens the home of the signed-in session's target ([homeFor]).
  static const root = '/';

  /// Where a Studio session opens: the connection list. New code reads [homeFor].
  static const home = connectionList;

  // Auth routes
  static const login = '/login';

  /// The introduction, shown once before the first sign-in. Like [login] it belongs to neither target, so it is left
  /// out of `_studioRoots` and `platformTabs` and [belongsTo] answers false for both.
  static const welcome = '/welcome';

  // Connection routes
  static const connectionList = '/connections';

  // The root of the Browse tab
  static const browse = '/browse';

  // The pages under the Browse root, relative to it. Each names its connection in the path and a container path as
  // repeated `container` query parameters, in order and never joined, leaving the key out for an empty path.

  /// The containers of the level under a parent container (`container`).
  static const browseContainers = ':connectionId/containers';

  /// The kind screen of a container (`container`).
  static const browseKinds = ':connectionId/kinds';

  /// The objects of one kind in a container (`container`).
  static const browseObjects = ':connectionId/objects/:kind';

  /// The source of an object of a kind, its path as repeated `path` query parameters.
  static const browseSource = ':connectionId/source/:kind';

  /// The key browser of a container (`container`), or of one level folder of it (`prefix`).
  static const browseKeys = ':connectionId/keys';

  /// The columns, indexes and foreign keys of an object of a kind, its path as repeated `path` query parameters.
  static const browseDetail = ':connectionId/detail/:kind';

  /// The name search across every container of a connection.
  static const browseSearch = ':connectionId/search';

  /// The first rows of an object of a kind, its path as repeated `path` query parameters.
  static const browseRows = ':connectionId/rows/:kind';

  /// The value of a Redis key walked in a container (`container`), the key as one `path` query parameter and the type
  /// its key browser page read as `type`.
  static const browseKeyValue = ':connectionId/value';

  // The root of the SQL tab
  static const sql = '/sql';

  /// The tabs of the Studio shell, in the order of its bottom navigation bar. New code reads [tabsFor].
  static const tabs = [connectionList, browse, sql];

  // Settings routes
  static const settings = '/settings';

  // Error routes
  static const notFound = '/not-found';

  // Platform routes: every route of a Platform session is under platformHome, and no Studio route is.

  /// Where a Platform session opens.
  static const platformHome = '/platform';

  /// The connections of the Platform tenant.
  static const platformConnections = '$platformHome/connections';

  /// The grants of one connection.
  static const platformConnectionGrants = '$platformConnections/:id';

  /// The editor of one grant of a connection.
  static const platformGrantEditor = '$platformConnectionGrants/grant';

  /// The settings of a Platform session, opened from the profile sheet like the Studio settings.
  static const platformSettings = '$platformHome/settings';

  /// The audit log of the install: governed query events, newest first.
  static const platformAudit = '$platformHome/audit';

  /// One event of the audit log, handed over by the list as route `extra`; the location carries no value of it.
  static const platformAuditEvent = '$platformAudit/event';

  /// The tabs of the Platform shell, in the order of its bottom navigation bar.
  static const platformTabs = [platformHome, platformConnections, platformAudit];

  /// The routes a Studio session owns, each with the paths under it.
  static const _studioRoots = [connectionList, browse, sql, settings];

  /// Where a session of [target] opens.
  static String homeFor(SessionTarget target) => switch (target) {
    SessionTarget.studio => connectionList,
    SessionTarget.platform => platformHome,
  };

  /// The tabs of the shell of [target], in the order of its bottom navigation bar.
  static List<String> tabsFor(SessionTarget target) => switch (target) {
    SessionTarget.studio => tabs,
    SessionTarget.platform => platformTabs,
  };

  /// The settings route of [target].
  static String settingsFor(SessionTarget target) => switch (target) {
    SessionTarget.studio => settings,
    SessionTarget.platform => platformSettings,
  };

  /// Whether a session of [target] may stay on [location], a path with or without a query: Platform owns
  /// [platformHome] and every path under it, Studio owns its tabs and settings and the paths under them. The root, the
  /// login page, the not-found page and an unknown path belong to neither.
  static bool belongsTo(SessionTarget target, String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    bool under(String root) => path == root || path.startsWith('$root/');
    return switch (target) {
      SessionTarget.studio => _studioRoots.any(under),
      SessionTarget.platform => under(platformHome),
    };
  }
}

/// Opens the SQL tab on [request]: its connection, its database and its text, which the editor puts in the field
/// without running it, asking first when the field holds another text. Any feature may call it.
///
/// The request travels as go_router `extra`, never in the location, since go_router logs every location it goes to;
/// the tab stays inside the shell, so no route is pushed above it.
void openEditor(BuildContext context, EditorOpenRequest request) =>
    context.go(ApplicationRoutesConstants.sql, extra: EditorOpenDelivery(request));
