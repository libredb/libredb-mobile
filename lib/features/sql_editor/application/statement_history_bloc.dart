import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';
import 'package:libredb_mobile/shared/utils/search_fold.dart';

part 'statement_history_event.dart';
part 'statement_history_state.dart';

/// The History sheet of the editor: the account's history on this phone, the active connection's entries by default,
/// with the local search, the status filter, a delete of one entry and Clear all.
///
/// Every event runs after the one before it, so a delete or a clear never meets a read still running. A history the
/// store cannot read is [StatementHistoryUnreadable], never empty, until the user discards it. Nothing here logs a
/// statement or the search text.
class StatementHistoryBloc extends Bloc<StatementHistoryEvent, StatementHistoryState> {
  StatementHistoryBloc({required this._repository, required this.subjectHash, required this.activeConnectionId})
    : super(const StatementHistoryLoading()) {
    on<StatementHistoryEvent>(
      (event, emit) => switch (event) {
        StatementHistoryLoadRequested() => _onLoad(emit),
        StatementHistorySearchChanged(:final query) => _onFilter(
          emit,
          (loaded) => loaded.copyWith(query: query, actionFailure: loaded.actionFailure),
        ),
        StatementHistoryScopeChanged(:final allConnections) => _onFilter(
          emit,
          (loaded) => loaded.copyWith(allConnections: allConnections, actionFailure: loaded.actionFailure),
        ),
        StatementHistoryStatusFilterChanged(:final filter) => _onFilter(
          emit,
          (loaded) => loaded.copyWith(statusFilter: filter, actionFailure: loaded.actionFailure),
        ),
        StatementHistoryEntryDeleted(:final entryId, :final done) => _onDelete(entryId, done, emit),
        StatementHistoryClearRequested() => _onClear(emit),
      },
      transformer: EventTransformers.queue(),
    );
  }

  static final _log = AppLogger.getLogger('StatementHistoryBloc');

  final IStatementHistoryRepository _repository;

  /// The account whose history this is, taken when the sheet opened.
  final String subjectHash;

  /// The connection open in the editor, whose entries show by default and can be put in the editor.
  final String activeConnectionId;

  Future<void> _onLoad(Emitter<StatementHistoryState> emit) async {
    emit(const StatementHistoryLoading());
    switch (await _repository.read(subjectHash)) {
      case Success(:final data):
        emit(StatementHistoryLoaded(entries: data, activeConnectionId: activeConnectionId));
      case Failure(:final error):
        _log.warn('history not read: {}', [error.code ?? error.runtimeType]);
        final code = _codeOf(error);
        emit(
          code == AppErrorCode.editorSavedTextUnreadable
              ? const StatementHistoryUnreadable()
              : StatementHistoryFailure(errorCode: code),
        );
    }
  }

  void _onFilter(Emitter<StatementHistoryState> emit, StatementHistoryLoaded Function(StatementHistoryLoaded) change) {
    if (state case final StatementHistoryLoaded loaded) emit(change(loaded));
  }

  Future<void> _onDelete(String entryId, Completer<bool>? done, Emitter<StatementHistoryState> emit) async {
    if (state is! StatementHistoryLoaded) {
      done?.complete(false);
      return;
    }
    // The entry leaves the list only once the store removed it, so a refused delete never shows it gone.
    final result = await _repository.delete(subjectHash, entryId);
    final loaded = state;
    if (loaded is! StatementHistoryLoaded) {
      done?.complete(false);
      return;
    }
    switch (result) {
      case Success():
        emit(loaded.copyWith(entries: [...loaded.entries.where((entry) => entry.id != entryId)], actionFailure: null));
        done?.complete(true);
      case Failure(:final error):
        _log.warn('history entry not deleted: {}', [error.code ?? error.runtimeType]);
        emit(loaded.copyWith(actionFailure: _codeOf(error)));
        done?.complete(false);
    }
  }

  Future<void> _onClear(Emitter<StatementHistoryState> emit) async {
    final before = state;
    switch (await _repository.clear(subjectHash)) {
      case Success():
        emit(switch (before) {
          StatementHistoryLoaded() => before.copyWith(entries: const [], actionFailure: null),
          StatementHistoryLoading() || StatementHistoryUnreadable() || StatementHistoryFailure() =>
            StatementHistoryLoaded(entries: const [], activeConnectionId: activeConnectionId),
        });
      case Failure(:final error):
        _log.warn('history not cleared: {}', [error.code ?? error.runtimeType]);
        final code = _codeOf(error);
        emit(switch (before) {
          StatementHistoryLoaded() => before.copyWith(actionFailure: code),
          StatementHistoryLoading() || StatementHistoryUnreadable() => StatementHistoryUnreadable(actionFailure: code),
          StatementHistoryFailure() => StatementHistoryFailure(errorCode: code),
        });
    }
  }

  static AppErrorCode _codeOf(AppError error) => AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
}
