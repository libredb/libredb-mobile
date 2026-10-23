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

  // The root of the SQL tab
  static const sql = '/sql';

  /// The tabs of the shell, in the order of its bottom navigation bar.
  static const tabs = [connectionList, browse, sql];

  // Settings routes
  static const settings = '/settings';

  // Error routes
  static const notFound = '/not-found';
}
