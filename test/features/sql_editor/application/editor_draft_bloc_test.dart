import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_draft_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

const _connection = 'seed:dev-postgres';
const _alice = 'alice-hash';
const _bob = 'bob-hash';
const _delay = Duration(milliseconds: 20);

Failure<T> _failure<T>(AppErrorCode code) => Failure<T>(UnknownError('store', code: code.key));

void main() {
  late MockIStatementTextStore store;

  setUp(() {
    store = MockIStatementTextStore();
    when(() => store.readDraft(any(), any())).thenAnswer((_) async => const Success(null));
    when(() => store.saveDraft(any(), any(), any())).thenAnswer((_) async => const Success(DraftSaveOutcome.kept));
    when(() => store.discardDraft(any(), any())).thenAnswer((_) async => const Success(null));
  });

  EditorDraftBloc build() => EditorDraftBloc(store: store, connectionId: _connection, saveDelay: _delay);

  List<StatementDraft> saved([String subject = _alice]) =>
      verify(() => store.saveDraft(subject, _connection, captureAny())).captured.cast<StatementDraft>();

  blocTest<EditorDraftBloc, EditorDraftState>(
    'without a subject keeps nothing and calls nothing',
    build: build,
    act: (bloc) => bloc
      ..add(const EditorDraftSubjectChanged(null))
      ..add(const EditorDraftTextChanged('select 1'))
      ..add(const EditorDraftFlushRequested()),
    wait: _delay * 3,
    expect: () => const [EditorDraftOff()],
    verify: (_) => verifyZeroInteractions(store),
  );

  test('starts in a state of its own, before the page tells it the account', () {
    final bloc = build();
    addTearDown(bloc.close);

    expect(bloc.state, const EditorDraftInitial());
  });

  blocTest<EditorDraftBloc, EditorDraftState>(
    'reads the draft of the connection for the subject, and with none saved has nothing to restore',
    build: build,
    act: (bloc) => bloc.add(const EditorDraftSubjectChanged(_alice)),
    expect: () => const [EditorDraftLoading(), EditorDraftKept()],
    verify: (_) => verify(() => store.readDraft(_alice, _connection)).called(1),
  );

  blocTest<EditorDraftBloc, EditorDraftState>(
    'restores the saved draft with its catalog, and does not save it again unchanged',
    setUp: () =>
        when(() => store.readDraft(_alice, _connection))
            .thenAnswer((_) async => const Success(StatementDraft(text: 'select 1', catalog: 'sales'))),
    build: build,
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('select 1', catalog: 'sales'));
    },
    wait: _delay * 3,
    expect: () => const [EditorDraftLoading(), EditorDraftRestored(StatementDraft(text: 'select 1', catalog: 'sales'))],
    verify: (_) => verifyNever(() => store.saveDraft(any(), any(), any())),
  );

  group('a text typed before Studio named the account', () {
    setUp(
      () =>
          when(() => store.readDraft(_alice, _connection))
              .thenAnswer((_) async => const Success(StatementDraft(text: 'older'))),
    );

    blocTest<EditorDraftBloc, EditorDraftState>(
      'and a saved draft ask which to keep, and nothing is saved meanwhile',
      build: build,
      act: (bloc) => bloc
        ..add(const EditorDraftTextChanged('typed'))
        ..add(const EditorDraftSubjectChanged(_alice))
        ..add(const EditorDraftFlushRequested()),
      wait: _delay * 3,
      expect: () => const [EditorDraftLoading(), EditorDraftConflict(StatementDraft(text: 'older'))],
      verify: (_) => verifyNever(() => store.saveDraft(any(), any(), any())),
    );

    blocTest<EditorDraftBloc, EditorDraftState>(
      'restores the saved draft when the user takes it, and saves nothing',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const EditorDraftTextChanged('typed'))
          ..add(const EditorDraftSubjectChanged(_alice));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorDraftConflictAnswered(restore: true));
      },
      wait: _delay * 3,
      expect: () => const [
        EditorDraftLoading(),
        EditorDraftConflict(StatementDraft(text: 'older')),
        EditorDraftRestored(StatementDraft(text: 'older')),
      ],
      verify: (bloc) async {
        await bloc.close();
        verifyNever(() => store.saveDraft(any(), any(), any()));
      },
    );

    blocTest<EditorDraftBloc, EditorDraftState>(
      'keeps the typed text when the user keeps it, and saves it as the draft',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const EditorDraftTextChanged('typed'))
          ..add(const EditorDraftSubjectChanged(_alice));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorDraftConflictAnswered(restore: false));
      },
      wait: _delay * 3,
      expect: () => const [EditorDraftLoading(), EditorDraftConflict(StatementDraft(text: 'older')), EditorDraftKept()],
      verify: (_) => expect(saved(), [const StatementDraft(text: 'typed')]),
    );

    blocTest<EditorDraftBloc, EditorDraftState>(
      'that is the saved draft itself restores it without asking',
      build: build,
      act: (bloc) => bloc
        ..add(const EditorDraftTextChanged('older'))
        ..add(const EditorDraftSubjectChanged(_alice)),
      expect: () => const [EditorDraftLoading(), EditorDraftRestored(StatementDraft(text: 'older'))],
    );

    blocTest<EditorDraftBloc, EditorDraftState>(
      'with no saved draft is saved as the draft',
      setUp: () => when(() => store.readDraft(_alice, _connection)).thenAnswer((_) async => const Success(null)),
      build: build,
      act: (bloc) => bloc
        ..add(const EditorDraftTextChanged('typed'))
        ..add(const EditorDraftSubjectChanged(_alice)),
      wait: _delay,
      expect: () => const [EditorDraftLoading(), EditorDraftKept()],
      verify: (_) => expect(saved(), [const StatementDraft(text: 'typed')]),
    );
  });

  blocTest<EditorDraftBloc, EditorDraftState>(
    'saves once after typing pauses, with the latest text',
    build: build,
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const EditorDraftTextChanged('s'))
        ..add(const EditorDraftTextChanged('se'))
        ..add(const EditorDraftTextChanged('sel'));
      await Future<void>.delayed(_delay ~/ 2);
      verifyNever(() => store.saveDraft(any(), any(), any()));
    },
    wait: _delay * 3,
    verify: (_) => expect(saved(), [const StatementDraft(text: 'sel')]),
  );

  blocTest<EditorDraftBloc, EditorDraftState>(
    'a flush saves the latest text at once, and the pause after it saves nothing more',
    build: () => EditorDraftBloc(store: store, connectionId: _connection, saveDelay: const Duration(seconds: 5)),
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const EditorDraftTextChanged('select 2'))
        ..add(const EditorDraftFlushRequested());
    },
    wait: _delay,
    verify: (_) => expect(saved(), [const StatementDraft(text: 'select 2')]),
  );

  test('closing saves the text that waited for its pause', () async {
    final bloc = EditorDraftBloc(store: store, connectionId: _connection, saveDelay: const Duration(seconds: 5));
    bloc.add(const EditorDraftSubjectChanged(_alice));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const EditorDraftTextChanged('select 3'));
    await bloc.close();

    expect(saved(), [const StatementDraft(text: 'select 3')]);
  });

  test('a new subject saves the waiting text for the account that typed it, then reads its own draft', () async {
    final bloc = EditorDraftBloc(store: store, connectionId: _connection, saveDelay: const Duration(seconds: 5));
    addTearDown(bloc.close);
    bloc.add(const EditorDraftSubjectChanged(_alice));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const EditorDraftTextChanged('typed by alice'));
    bloc.add(const EditorDraftSubjectChanged(_bob));
    await Future<void>.delayed(_delay);

    expect(saved(), [const StatementDraft(text: 'typed by alice')]);
    verify(() => store.readDraft(_bob, _connection)).called(1);
    verifyNever(() => store.saveDraft(_bob, any(), any()));
  });

  blocTest<EditorDraftBloc, EditorDraftState>(
    'a text over the bound is not kept, said once, and a shorter text after it is kept again',
    setUp: () => when(() => store.saveDraft(_alice, _connection, any())).thenAnswer(
      (invocation) async => Success(
        (invocation.positionalArguments[2] as StatementDraft).text.length > 5
            ? DraftSaveOutcome.notKept
            : DraftSaveOutcome.kept,
      ),
    ),
    build: build,
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('too long'));
      await Future<void>.delayed(_delay * 2);
      bloc.add(const EditorDraftTextChanged('longer still'));
      await Future<void>.delayed(_delay * 2);
      bloc.add(const EditorDraftTextChanged('short'));
    },
    wait: _delay * 3,
    expect: () => const [EditorDraftLoading(), EditorDraftKept(), EditorDraftNotKept(), EditorDraftKept()],
  );

  blocTest<EditorDraftBloc, EditorDraftState>(
    'after a text over the bound, an empty field saves no empty draft, since the store holds none',
    setUp: () =>
        when(() => store.saveDraft(_alice, _connection, any()))
            .thenAnswer((_) async => const Success(DraftSaveOutcome.notKept)),
    build: build,
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('far too long'));
      await Future<void>.delayed(_delay * 2);
      bloc.add(const EditorDraftTextChanged(''));
    },
    wait: _delay * 3,
    verify: (bloc) async {
      await bloc.close();
      expect(saved(), [const StatementDraft(text: 'far too long')]);
    },
  );

  group('a save after the editor closed', () {
    late List<EditorDraftState> late;

    setUp(() => late = []);

    EditorDraftBloc lateBuild() => EditorDraftBloc(
      store: store,
      connectionId: _connection,
      saveDelay: const Duration(seconds: 5),
      onLateOutcome: late.add,
    );

    test('that the device refuses is reported', () async {
      when(() => store.saveDraft(_alice, _connection, any()))
          .thenAnswer((_) async => _failure(AppErrorCode.editorSavedTextNotStored));
      final bloc = lateBuild();
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('select 1'));
      await bloc.close();
      await Future<void>.delayed(Duration.zero);

      expect(late, [const EditorDraftSaveFailed(AppErrorCode.editorSavedTextNotStored)]);
    });

    test('that is over the bound is reported as not kept', () async {
      when(() => store.saveDraft(_alice, _connection, any()))
          .thenAnswer((_) async => const Success(DraftSaveOutcome.notKept));
      final bloc = lateBuild();
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('far too long'));
      await bloc.close();
      await Future<void>.delayed(Duration.zero);

      expect(late, [const EditorDraftNotKept()]);
    });

    test('that is kept reports nothing', () async {
      final bloc = lateBuild();
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('select 1'));
      await bloc.close();
      await Future<void>.delayed(Duration.zero);

      expect(late, isEmpty);
    });

    test('for the previous account on an account change, refused, is reported', () async {
      when(() => store.saveDraft(_alice, _connection, any()))
          .thenAnswer((_) async => _failure(AppErrorCode.editorSavedTextNotStored));
      final bloc = lateBuild();
      addTearDown(bloc.close);
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const EditorDraftTextChanged('typed by alice'))
        ..add(const EditorDraftSubjectChanged(_bob));
      await Future<void>.delayed(_delay);

      expect(late, [const EditorDraftSaveFailed(AppErrorCode.editorSavedTextNotStored)]);
    });
  });

  blocTest<EditorDraftBloc, EditorDraftState>(
    'a save the device refuses is shown, and the next save that works clears it',
    setUp: () {
      var calls = 0;
      when(() => store.saveDraft(_alice, _connection, any())).thenAnswer(
        (_) async =>
            calls++ == 0 ? _failure(AppErrorCode.editorSavedTextNotStored) : const Success(DraftSaveOutcome.kept),
      );
    },
    build: build,
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('a'));
      await Future<void>.delayed(_delay * 2);
      bloc.add(const EditorDraftTextChanged('ab'));
    },
    wait: _delay * 3,
    expect: () => const [
      EditorDraftLoading(),
      EditorDraftKept(),
      EditorDraftSaveFailed(AppErrorCode.editorSavedTextNotStored),
      EditorDraftKept(),
    ],
  );

  blocTest<EditorDraftBloc, EditorDraftState>(
    'a failed save of a text is tried again when the same text is flushed',
    setUp: () {
      var calls = 0;
      when(() => store.saveDraft(_alice, _connection, any())).thenAnswer(
        (_) async =>
            calls++ == 0 ? _failure(AppErrorCode.editorSavedTextNotStored) : const Success(DraftSaveOutcome.kept),
      );
    },
    build: build,
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('a'));
      await Future<void>.delayed(_delay * 2);
      bloc.add(const EditorDraftFlushRequested());
    },
    wait: _delay,
    verify: (_) => expect(saved(), [const StatementDraft(text: 'a'), const StatementDraft(text: 'a')]),
  );

  group('an unreadable saved draft', () {
    setUp(
      () =>
          when(() => store.readDraft(_alice, _connection))
              .thenAnswer((_) async => _failure(AppErrorCode.editorSavedTextUnreadable)),
    );

    blocTest<EditorDraftBloc, EditorDraftState>(
      'is shown, and no text replaces it while it stays',
      build: build,
      act: (bloc) async {
        bloc.add(const EditorDraftSubjectChanged(_alice));
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const EditorDraftTextChanged('new text'))
          ..add(const EditorDraftFlushRequested());
      },
      wait: _delay * 3,
      expect: () => const [EditorDraftLoading(), EditorDraftUnreadable()],
      verify: (bloc) async {
        await bloc.close();
        verifyNever(() => store.saveDraft(any(), any(), any()));
      },
    );

    blocTest<EditorDraftBloc, EditorDraftState>(
      'Discard removes it, and the text typed meanwhile is saved',
      build: build,
      act: (bloc) async {
        bloc.add(const EditorDraftSubjectChanged(_alice));
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const EditorDraftTextChanged('new text'))
          ..add(const EditorDraftDiscardRequested());
      },
      wait: _delay * 3,
      expect: () => const [EditorDraftLoading(), EditorDraftUnreadable(), EditorDraftKept()],
      verify: (_) {
        verify(() => store.discardDraft(_alice, _connection)).called(1);
        expect(saved(), [const StatementDraft(text: 'new text')]);
      },
    );

    blocTest<EditorDraftBloc, EditorDraftState>(
      'a Discard that fails keeps it and says why',
      setUp: () =>
          when(() => store.discardDraft(_alice, _connection))
              .thenAnswer((_) async => _failure(AppErrorCode.editorSavedTextNotStored)),
      build: build,
      act: (bloc) async {
        bloc.add(const EditorDraftSubjectChanged(_alice));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorDraftDiscardRequested());
      },
      expect: () => const [
        EditorDraftLoading(),
        EditorDraftUnreadable(),
        EditorDraftUnreadable(discardFailure: AppErrorCode.editorSavedTextNotStored),
      ],
      verify: (_) => verifyNever(() => store.saveDraft(any(), any(), any())),
    );
  });

  blocTest<EditorDraftBloc, EditorDraftState>(
    'a save that finds the saved draft unreadable shows it like a read that did',
    setUp: () =>
        when(() => store.saveDraft(_alice, _connection, any()))
            .thenAnswer((_) async => _failure(AppErrorCode.editorSavedTextUnreadable)),
    build: build,
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const EditorDraftTextChanged('x'));
    },
    wait: _delay * 3,
    expect: () => const [EditorDraftLoading(), EditorDraftKept(), EditorDraftUnreadable()],
  );

  blocTest<EditorDraftBloc, EditorDraftState>(
    'a read that fails otherwise is shown, saves nothing, and Retry reads again',
    setUp: () {
      var calls = 0;
      when(() => store.readDraft(_alice, _connection)).thenAnswer(
        (_) async => calls++ == 0 ? _failure(AppErrorCode.generic) : const Success(StatementDraft(text: 'select 1')),
      );
    },
    build: build,
    act: (bloc) async {
      bloc.add(const EditorDraftSubjectChanged(_alice));
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const EditorDraftTextChanged(''))
        ..add(const EditorDraftFlushRequested());
      await Future<void>.delayed(_delay * 2);
      bloc.add(const EditorDraftRetryRequested());
    },
    wait: _delay,
    expect: () => const [
      EditorDraftLoading(),
      EditorDraftReadFailed(AppErrorCode.generic),
      EditorDraftLoading(),
      EditorDraftRestored(StatementDraft(text: 'select 1')),
    ],
    verify: (_) => verifyNever(() => store.saveDraft(any(), any(), any())),
  );
}
