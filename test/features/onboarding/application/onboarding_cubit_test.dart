import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

/// Whether this launch has to show the introduction, settled before the first frame.
///
/// Two of its rules are safety rules rather than behaviour, and both are pinned here because neither is visible on
/// screen until the route exists and both are easy to invert while refactoring:
///
/// - a read that fails means **seen**, never "show it again"; and
/// - a write that the device refuses still leaves the user past the introduction.
///
/// The third thing worth a test is that nothing is decided before the read answers: the state starts at
/// [OnboardingRestoring] and the app waits on it, so a first run never paints the login page and then jumps.
///
/// Every emit is guarded by `isClosed`, and each guard gets a test of its own. A guard the suite does not reach
/// survives the refactor that deletes it, and what it leaves behind is an emit on a closed cubit: it throws in debug,
/// is silent in release, and surfaces far from its cause.
void main() {
  late MockIOnboardingSeenStore store;

  setUp(() => store = MockIOnboardingSeenStore());

  /// The ordinary device: reading answers [seen] and writing succeeds.
  void storeAnswers({required bool seen}) {
    when(() => store.read()).thenAnswer((_) async => seen);
    when(() => store.write()).thenAnswer((_) async {});
  }

  group('the state before any read', () {
    test('is restoring, so nothing decides what to show before the answer arrives', () {
      storeAnswers(seen: false);

      expect(OnboardingCubit(store: store).state, const OnboardingRestoring());
    });
  });

  group('restore', () {
    test('requires the introduction on a device that has never shown it', () async {
      storeAnswers(seen: false);
      final cubit = OnboardingCubit(store: store);

      await cubit.restore();

      expect(cubit.state, const OnboardingRequired());
    });

    test('does not require it on a device that has', () async {
      storeAnswers(seen: true);
      final cubit = OnboardingCubit(store: store);

      await cubit.restore();

      expect(cubit.state, const OnboardingSeen());
    });

    test('treats a failed read as seen, so a storage hiccup cannot trap a returning user in it', () async {
      when(() => store.read()).thenThrow(StateError('the device refused to answer'));
      final cubit = OnboardingCubit(store: store);

      await cubit.restore();

      expect(cubit.state, const OnboardingSeen());
    });

    test('emits each state once, so the app-level wait is not asked twice', () async {
      storeAnswers(seen: false);
      final cubit = OnboardingCubit(store: store);
      final emitted = <OnboardingState>[];
      cubit.stream.listen(emitted.add);

      await cubit.restore();
      await Future<void>.delayed(Duration.zero);

      expect(emitted, const [OnboardingRequired()]);
    });
  });

  group('markSeen', () {
    test('leaves the introduction behind', () async {
      storeAnswers(seen: false);
      final cubit = OnboardingCubit(store: store);
      await cubit.restore();

      await cubit.markSeen();

      expect(cubit.state, const OnboardingSeen());
    });

    test('stores it, so the next launch does not show it again', () async {
      storeAnswers(seen: false);

      await OnboardingCubit(store: store).markSeen();

      verify(() => store.write()).called(1);
    });

    test('applies on screen before the write, because the user has already finished reading it', () async {
      // The order matters on a slow device: waiting for the write would hold the user on the last panel after they
      // pressed Done. CollapsedSectionsCubit settles the same question the same way.
      final write = Completer<void>();
      when(() => store.write()).thenAnswer((_) => write.future);
      final cubit = OnboardingCubit(store: store);

      final pending = cubit.markSeen();

      expect(cubit.state, const OnboardingSeen());
      write.complete();
      await pending;
    });

    test('leaves the introduction behind even when the device refuses to store it', () async {
      when(() => store.write()).thenThrow(StateError('the device refused to store onboarding_seen'));
      final cubit = OnboardingCubit(store: store);

      await cubit.markSeen();

      expect(cubit.state, const OnboardingSeen());
    });

    test('is idempotent, because a second pass through the flow is not an error', () async {
      storeAnswers(seen: false);
      final cubit = OnboardingCubit(store: store);

      await cubit.markSeen();
      await cubit.markSeen();

      expect(cubit.state, const OnboardingSeen());
      verify(() => store.write()).called(2);
    });
  });

  // One test per guard: three guards, three paths. Together they are why a refactor cannot quietly drop one.
  group('after close', () {
    test('a read that answers late emits nothing', () async {
      final read = Completer<bool>();
      when(() => store.read()).thenAnswer((_) => read.future);
      final cubit = OnboardingCubit(store: store);

      final pending = cubit.restore();
      await cubit.close();
      read.complete(false);

      await expectLater(pending, completes);
    });

    test('a read that fails late emits nothing, which is a second guard on a second path', () async {
      final read = Completer<bool>();
      when(() => store.read()).thenAnswer((_) => read.future);
      final cubit = OnboardingCubit(store: store);

      final pending = cubit.restore();
      await cubit.close();
      read.completeError(StateError('the device refused to answer'));

      await expectLater(pending, completes);
    });

    test('markSeen emits nothing, so a flow closing as the user presses Done does not throw', () async {
      storeAnswers(seen: false);
      final cubit = OnboardingCubit(store: store);
      await cubit.close();

      await expectLater(cubit.markSeen(), completes);
    });
  });
}
