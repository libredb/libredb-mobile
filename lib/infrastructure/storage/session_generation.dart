/// Counts the wipes of the stored session, so work that started under one session can tell, before it stores anything
/// for it, that the session ended in the meantime.
///
/// `AuthInterceptor` records the generation a request is sent under before it reads the token. When the request gets
/// a 401, `TokenRefreshInterceptor` sends it again or refreshes the session only while that generation has not ended,
/// and checks it again before and after it stores the rotated tokens. A logout or the end of the session wipes the
/// stored session through [wipe], so a refresh still on its way drops the rotated tokens instead of storing a session
/// the user ended, which a relaunch would restore.
///
/// A sign-out the user starts runs inside [signOut], from before its first request until its wipe has ended, so
/// `AuthInterceptor` sends no other request of the session meanwhile ([signingOut]).
///
/// The generation lives in memory, so it counts the wipes of one app process, which holds the stored session alone.
abstract final class SessionGeneration {
  static int _current = 0;
  static int _wipesRunning = 0;
  static int _signOutsRunning = 0;

  /// The generation of the stored session.
  static int get current => _current;

  /// Whether the session of [generation] has ended: a wipe has run since [generation] was read, or one is running.
  static bool hasEnded(int generation) => _wipesRunning > 0 || generation != _current;

  /// Whether a sign-out the user started is running ([signOut]).
  static bool get signingOut => _signOutsRunning > 0;

  /// Whether a wipe of the stored session is running ([wipe]).
  static bool get wiping => _wipesRunning > 0;

  /// Runs [body], the sign-out the user started, as a sign-out: [signingOut] holds until [body] completes or throws.
  ///
  /// It ends no generation itself: the wipe inside [body] does, through [wipe]. Only the requests of the sign-out,
  /// such as Studio's sign-out record, still leave while it runs.
  static Future<T> signOut<T>(Future<T> Function() body) async {
    _signOutsRunning++;
    try {
      return await body();
    } finally {
      _signOutsRunning--;
    }
  }

  /// Runs [body], which wipes the stored session, as the end of the current generation.
  ///
  /// A new generation starts before [body] makes its first storage call and another once it ends, and [hasEnded] holds
  /// for every generation while it runs. So a refresh that read the refresh token before the wipe deleted it, or that
  /// asks for the generation while the wipe runs, does not leave the rotated tokens stored: it drops them when its
  /// session ended before it stores them, and takes back what it stored when a wipe ran meanwhile, a write that landed
  /// after the wipe included. The wipe ends when [body] completes or throws.
  static Future<T> wipe<T>(Future<T> Function() body) async {
    _current++;
    _wipesRunning++;
    try {
      return await body();
    } finally {
      _wipesRunning--;
      _current++;
    }
  }
}
