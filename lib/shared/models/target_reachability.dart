/// Whether a target's server answers its liveness check, as the login page shows it on that target's entry.
enum TargetReachability {
  /// No answer yet, or no check asked. The entry is enabled: a check never holds the sign-in back.
  unknown,

  /// The server answered.
  reachable,

  /// The server did not answer, and a new check runs. The entry stays disabled until it answers.
  checking,

  /// The server did not answer. The entry is disabled and offers a retry.
  unreachable;

  /// Whether the entry of a target in this state is disabled.
  bool get blocksSignIn => switch (this) {
    TargetReachability.checking || TargetReachability.unreachable => true,
    TargetReachability.unknown || TargetReachability.reachable => false,
  };
}
