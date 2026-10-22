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

  // The root of the SQL tab
  static const sql = '/sql';

  /// The tabs of the shell, in the order of its bottom navigation bar.
  static const tabs = [connectionList, browse, sql];

  // Settings routes
  static const settings = '/settings';

  // Error routes
  static const notFound = '/not-found';
}
