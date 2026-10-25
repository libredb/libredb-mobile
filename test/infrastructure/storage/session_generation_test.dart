import 'dart:async';

import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionGeneration', () {
    test('a sign-out counts as running from its start until its body ends, and ends no generation itself', () async {
      final before = SessionGeneration.current;
      final release = Completer<void>();

      final signOut = SessionGeneration.signOut(() => release.future);

      expect(SessionGeneration.signingOut, isTrue);
      expect(SessionGeneration.hasEnded(before), isFalse, reason: 'only the wipe inside a sign-out ends the session');
      release.complete();
      await signOut;
      expect(SessionGeneration.signingOut, isFalse);
    });

    test('a sign-out that throws stops running, and its error reaches the caller', () async {
      await expectLater(
        SessionGeneration.signOut<void>(() async => throw StateError('sign-out failed')),
        throwsStateError,
      );

      expect(SessionGeneration.signingOut, isFalse);
    });

    test('a generation read before a wipe has ended once the wipe starts', () async {
      final before = SessionGeneration.current;
      final releaseWipe = Completer<void>();

      final wipe = SessionGeneration.wipe(() => releaseWipe.future);

      expect(SessionGeneration.hasEnded(before), isTrue);
      releaseWipe.complete();
      await wipe;
      expect(SessionGeneration.hasEnded(before), isTrue);
    });

    test('a generation read while a wipe runs has ended, also once the wipe finishes', () async {
      final releaseWipe = Completer<void>();
      final wipe = SessionGeneration.wipe(() => releaseWipe.future);

      final duringWipe = SessionGeneration.current;
      expect(SessionGeneration.hasEnded(duringWipe), isTrue);
      releaseWipe.complete();
      await wipe;

      expect(SessionGeneration.hasEnded(duringWipe), isTrue);
    });

    test('a generation read after the wipe has not ended', () async {
      await SessionGeneration.wipe(() async {});

      expect(SessionGeneration.hasEnded(SessionGeneration.current), isFalse);
    });

    test('a wipe that throws ends too, and its error reaches the caller', () async {
      final before = SessionGeneration.current;

      await expectLater(SessionGeneration.wipe<void>(() async => throw StateError('storage failed')), throwsStateError);

      expect(SessionGeneration.hasEnded(before), isTrue);
      expect(SessionGeneration.hasEnded(SessionGeneration.current), isFalse);
    });

    test('the session counts as ended until the last of two overlapping wipes finishes', () async {
      final releaseFirst = Completer<void>();
      final releaseSecond = Completer<void>();
      final first = SessionGeneration.wipe(() => releaseFirst.future);
      final second = SessionGeneration.wipe(() => releaseSecond.future);

      releaseFirst.complete();
      await first;
      expect(SessionGeneration.hasEnded(SessionGeneration.current), isTrue);
      releaseSecond.complete();
      await second;
      expect(SessionGeneration.hasEnded(SessionGeneration.current), isFalse);
    });
  });
}
