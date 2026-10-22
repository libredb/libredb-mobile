/// Fixed instant for fixtures whose timestamp value is arbitrary. Use this
/// instead of DateTime.now() so a fixture never depends on wall-clock time.
final DateTime kTestInstant = DateTime.utc(2024, 1, 1, 12);
