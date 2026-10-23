/// Routes for the application
///
/// This class contains all the routes used in the application.
class ApplicationRoutesConstants {
  /// The root of the app, which opens [home].
  static const root = '/';

  /// Where the app opens after sign-in: the connection list.
  static const home = connectionList;

  // Auth routes
  static const login = '/login';

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

  // The root of the SQL tab
  static const sql = '/sql';

  /// The tabs of the shell, in the order of its bottom navigation bar.
  static const tabs = [connectionList, browse, sql];

  // Settings routes
  static const settings = '/settings';

  // Error routes
  static const notFound = '/not-found';
}
