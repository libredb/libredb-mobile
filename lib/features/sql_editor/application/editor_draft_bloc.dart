import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'editor_draft_event.dart';
part 'editor_draft_state.dart';

/// The draft of one connection's editor: it restores the text the account saved for the connection, and saves the text
/// through [IStatementTextStore] once typing pauses for [saveDelay], when the app goes to the background
/// ([EditorDraftFlushRequested]) and when the editor closes.
///
/// It reads and saves only for the account Studio named ([EditorDraftSubjectChanged]), and a save always goes to the
/// account the text was typed for. A text over the store's bound is not kept and says so ([EditorDraftNotKept]); a
/// refused save is shown ([EditorDraftSaveFailed]); a saved draft that cannot be read stays until the user discards
/// it, and no text is saved over it before that ([EditorDraftUnreadable]).
class EditorDraftBloc extends Bloc<EditorDraftEvent, EditorDraftState> {
  EditorDraftBloc({
    required this._store,
    required this.connectionId,
    this.saveDelay = defaultSaveDelay,
    this.onLateOutcome,
  }) : super(const EditorDraftOff()) {
    on<EditorDraftSubjectChanged>(_onSubjectChanged, transformer: EventTransformers.queue());
    // The pause is a timer of the bloc's own rather than a debouncing transformer: stream_transform's debounce emits its
    // last event when the bloc closes and keeps its timer running after the editor is gone, while close() saves the
    // waiting text itself and cancels this timer.
    on<EditorDraftTextChanged>((event, emit) {
      _pause?.cancel();
      _pause = Timer(saveDelay, () => add(const EditorDraftFlushRequested()));
    });
    // One save at a time, so a save that is still running is never dropped with its answer.
    on<EditorDraftFlushRequested>((event, emit) => _saveLatest(emit), transformer: EventTransformers.queue());
    on<EditorDraftDiscardRequested>(_onDiscard, transformer: EventTransformers.dropConcurrent());
    on<EditorDraftRetryRequested>(_onRetry, transformer: EventTransformers.dropConcurrent());
    on<EditorDraftConflictAnswered>(_onConflictAnswered, transformer: EventTransformers.dropConcurrent());
  }

  static const defaultSaveDelay = Duration(seconds: 1);

  static final _log = AppLogger.getLogger('EditorDraftBloc');

  final IStatementTextStore _store;
  final String connectionId;

  /// How long typing pauses before the text is saved.
  final Duration saveDelay;

  /// Told what became of a save this bloc can no longer show as its state, when it was not kept: the save as the
  /// editor closes, and the save for the previous account on an account change. It gets [EditorDraftNotKept],
  /// [EditorDraftSaveFailed] or [EditorDraftUnreadable], for a screen that outlives the editor to say.
  final void Function(EditorDraftState outcome)? onLateOutcome;

  /// The subject hash of the account the drafts are read and saved for.
  String? _subject;

  /// The latest text of the field, taken when its event is added, so a flush and a close save what the field holds.
  StatementDraft? _latest;

  /// The draft the store holds for the connection as far as this bloc knows: the one restored or last saved.
  StatementDraft? _stored;

  /// Runs while typing pauses, and saves the text when it ends.
  Timer? _pause;

  /// Counts the reads, so the answer of a read for an earlier subject is never applied.
  int _reads = 0;

  @override
  void onEvent(EditorDraftEvent event) {
    if (event case EditorDraftTextChanged(:final text, :final catalog)) {
      _latest = StatementDraft(text: text, catalog: catalog);
    }
    super.onEvent(event);
  }

  @override
  Future<void> close() {
    _pause?.cancel();
    // The editor closes when the user leaves the tab or switches the connection: the text waiting for its pause is
    // saved now, and the store finishes the write after this bloc is gone.
    if ((_subject, _pending) case (final subject?, final draft?)) _saveLate(subject, draft);
    return super.close();
  }

  bool get _canSave => switch (state) {
    EditorDraftRestored() || EditorDraftKept() || EditorDraftNotKept() || EditorDraftSaveFailed() => true,
    EditorDraftOff() ||
    EditorDraftLoading() ||
    EditorDraftConflict() ||
    EditorDraftUnreadable() ||
    EditorDraftReadFailed() => false,
  };

  /// The latest text when it has to be saved: a subject is named, nothing unread stands in the way, and the store does
  /// not hold it already.
  StatementDraft? get _pending {
    final latest = _latest;
    if (_subject == null || latest == null || !_canSave || latest == _stored) return null;
    if (_stored == null && latest.text.isEmpty) return null;
    return latest;
  }

  Future<void> _onSubjectChanged(EditorDraftSubjectChanged event, Emitter<EditorDraftState> emit) async {
    final previous = _subject;
    if (event.subjectHash == previous) return;
    if (previous != null) {
      // The text was typed for the previous account, so it is saved there and is not the next account's draft.
      if (_pending case final draft?) _saveLate(previous, draft);
      _latest = null;
    }
    _subject = event.subjectHash;
    _stored = null;
    _reads++;
    if (_subject == null) {
      _log.info('Studio named no account, so the draft is not kept on this device');
      emit(const EditorDraftOff());
      return;
    }
    await _read(emit);
  }

  Future<void> _onRetry(EditorDraftRetryRequested event, Emitter<EditorDraftState> emit) async {
    if (state is EditorDraftReadFailed) await _read(emit);
  }

  Future<void> _read(Emitter<EditorDraftState> emit) async {
    final subject = _subject!;
    final read = ++_reads;
    emit(const EditorDraftLoading());
    final result = await _store.readDraft(subject, connectionId);
    if (read != _reads) return;
    switch (result) {
      case Success(:final data):
        _stored = data;
        final typed = _latest;
        if (data != null && typed != null && typed.text.isNotEmpty && typed.text != data.text) {
          // A text typed before Studio named the account replaces nothing without the user's word.
          emit(EditorDraftConflict(data));
          return;
        }
        if (data != null) {
          // The field shows the restored draft from now on.
          _latest = data;
          emit(EditorDraftRestored(data));
          return;
        }
        emit(const EditorDraftKept());
        await _saveLatest(emit);
      case Failure(:final error):
        final code = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        emit(
          code == AppErrorCode.editorSavedTextUnreadable ? const EditorDraftUnreadable() : EditorDraftReadFailed(code),
        );
    }
  }

  Future<void> _saveLatest(Emitter<EditorDraftState> emit) async {
    final subject = _subject;
    final draft = _pending;
    if (subject == null || draft == null) return;
    _stored = draft;
    final result = await _store.saveDraft(subject, connectionId, draft);
    if (subject != _subject) return;
    switch (result) {
      case Success(data: DraftSaveOutcome.kept):
        emit(const EditorDraftKept());
      case Success(data: DraftSaveOutcome.notKept):
        // The store removed the connection's draft, so it holds none: an empty field after this saves nothing.
        if (_stored == draft) _stored = null;
        emit(const EditorDraftNotKept());
      case Failure(:final error):
        // Not stored, so the same text is saved again on the next pause or flush.
        if (_stored == draft) _stored = null;
        final code = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        emit(
          code == AppErrorCode.editorSavedTextUnreadable ? const EditorDraftUnreadable() : EditorDraftSaveFailed(code),
        );
    }
  }

  /// Saves [draft] for [subject] after this bloc stopped showing saves, and tells [onLateOutcome] when it was not kept.
  void _saveLate(String subject, StatementDraft draft) {
    unawaited(
      _store.saveDraft(subject, connectionId, draft).then((result) {
        final outcome = switch (result) {
          Success(data: DraftSaveOutcome.kept) => null,
          Success(data: DraftSaveOutcome.notKept) => const EditorDraftNotKept(),
          Failure(:final error) => switch (AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic) {
            AppErrorCode.editorSavedTextUnreadable => const EditorDraftUnreadable(),
            final code => EditorDraftSaveFailed(code),
          },
        };
        if (outcome != null) onLateOutcome?.call(outcome);
      }),
    );
  }

  Future<void> _onConflictAnswered(EditorDraftConflictAnswered event, Emitter<EditorDraftState> emit) async {
    if (state case EditorDraftConflict(:final draft)) {
      if (event.restore) {
        _latest = draft;
        emit(EditorDraftRestored(draft));
        return;
      }
      emit(const EditorDraftKept());
      await _saveLatest(emit);
    }
  }

  Future<void> _onDiscard(EditorDraftDiscardRequested event, Emitter<EditorDraftState> emit) async {
    final subject = _subject;
    if (subject == null || state is! EditorDraftUnreadable) return;
    switch (await _store.discardDraft(subject, connectionId)) {
      case Success():
        if (subject != _subject) return;
        _stored = null;
        emit(const EditorDraftKept());
        await _saveLatest(emit);
      case Failure(:final error):
        if (subject != _subject) return;
        emit(EditorDraftUnreadable(discardFailure: AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic));
    }
  }
}
