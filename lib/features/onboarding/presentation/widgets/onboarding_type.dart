/// The natural line of the two faces the introduction is set in, as a multiplier of the size.
///
/// The prototype leaves most of its lines at `line-height:normal`, which is the face's own ascent plus descent plus
/// gap: measured in headless Chrome at a device scale of 2, JetBrains Mono 11px is 14.5 (1.32) and Plus Jakarta Sans
/// 11.5px is 14.5 (1.26). Flutter's natural line is the same sum, so on a phone leaving `height` out would do — but
/// `flutter test` draws in Ahem, whose line is 1.0, so a box measured in a test would be a third off. Writing the
/// face's own ratio gives the line in both, and the boxes round it are then the same number on the phone and under
/// test.
const double onboardingMonoLine = 1.32;
const double onboardingSansLine = 1.26;
