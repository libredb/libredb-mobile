import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_cubit.dart';
import 'package:libredb_mobile/features/onboarding/application/onboarding_state.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/onboarding_seen_store.dart';

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
void main() {
  group('the state before any read', () {
    test('is restoring, so nothing decides what to show before the answer arrives', () {
      final cubit = OnboardingCubit(store: _StubStore(seen: false));

      expect(cubit.state, const OnboardingRestoring());
    });
  });

  group('restore', () {
    test('requires the introduction on a device that has never shown it', () async {
      final cubit = OnboardingCubit(store: _StubStore(seen: false));

      await cubit.restore();

      expect(cubit.state, const OnboardingRequired());
    });

    test('does not require it on a device that has', () async {
      final cubit = OnboardingCubit(store: _StubStore(seen: true));

      await cubit.restore();

      expect(cubit.state, const OnboardingSeen());
    });

    test(
      'treats a failed read as seen, so a storage hiccup cannot trap a returning user in the introduction',
      () async {
        final cubit = OnboardingCubit(store: _ThrowingStore());

        await cubit.restore();

        expect(cubit.state, const OnboardingSeen());
      },
    );

    test('emits each state once, so the app-level wait is not asked twice', () async {
      final cubit = OnboardingCubit(store: _StubStore(seen: false));
      final emitted = <OnboardingState>[];
      cubit.stream.listen(emitted.add);

      await cubit.restore();
      await Future<void>.delayed(Duration.zero);

      expect(emitted, const [OnboardingRequired()]);
    });
  });

  group('markSeen', () {
    test('leaves the introduction behind', () async {
      final store = _StubStore(seen: false);
      final cubit = OnboardingCubit(store: store);
      await cubit.restore();

      await cubit.markSeen();

      expect(cubit.state, const OnboardingSeen());
    });

    test('stores it, so the next launch does not show it again', () async {
      final store = _StubStore(seen: false);
      final cubit = OnboardingCubit(store: store);

      await cubit.markSeen();

      expect(store.writes, 1);
    });

    test('applies on screen before the write, because the user has already finished reading it', () async {
      // The order matters on a slow device: waiting for the write would hold the user on the last panel after they
      // pressed Done. CollapsedSectionsCubit settles the same question the same way.
      final store = _HeldStore();
      final cubit = OnboardingCubit(store: store);

      final pending = cubit.markSeen();

      expect(cubit.state, const OnboardingSeen());
      store.release();
      await pending;
    });

    test('leaves the introduction behind even when the device refuses to store it', () async {
      final cubit = OnboardingCubit(store: _ThrowingStore());

      await cubit.markSeen();

      expect(cubit.state, const OnboardingSeen());
    });

    test('is idempotent, because a second pass through the flow is not an error', () async {
      final store = _StubStore(seen: false);
      final cubit = OnboardingCubit(store: store);

      await cubit.markSeen();
      await cubit.markSeen();

      expect(cubit.state, const OnboardingSeen());
      expect(store.writes, 2);
    });
  });

  group('after close', () {
    test('a read that answers late emits nothing, so a disposed cubit does not throw', () async {
      final store = _HeldStore(seen: false);
      final cubit = OnboardingCubit(store: store);

      final pending = cubit.restore();
      await cubit.close();
      store.release();

      await expectLater(pending, completes);
    });
  });
}

/// Answers [seen] and counts the writes.
class _StubStore implements IOnboardingSeenStore {
  _StubStore({required this.seen});

  bool seen;
  int writes = 0;

  @override
  Future<bool> read() async => seen;

  @override
  Future<void> write() async {
    writes++;
    seen = true;
  }
}

/// Fails both ways, like a device whose preferences cannot be opened.
class _ThrowingStore implements IOnboardingSeenStore {
  @override
  Future<bool> read() async => throw StateError('the device refused to answer');

  @override
  Future<void> write() async => throw StateError('the device refused to store onboarding_seen');
}

/// Answers only once [release] is called, like a slow device.
class _HeldStore implements IOnboardingSeenStore {
  _HeldStore({this.seen = false});

  final bool seen;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<bool> read() async {
    await _gate.future;
    return seen;
  }

  @override
  Future<void> write() => _gate.future;
}
