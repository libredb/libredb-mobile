import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/features/object_browser/domain/row_count.dart';
import 'package:libredb_mobile/shared/models/query_id.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'row_count_event.dart';
part 'row_count_state.dart';

/// Counts the rows of one object of [connectionId] when the user taps Count rows: one run of Studio's count statement
/// per tap, with a fresh run id, and a tap while one runs dropped. Studio opens the same statement for editing and does
/// not run it; the phone runs it on the tap, a single read.
///
/// A refused count is kept as the error itself, for one line saying the count could not be loaded; it never fails the
/// page around it. Neither the statement nor a database error text is logged.
class RowCountBloc extends Bloc<RowCountEvent, RowCountState> {
  RowCountBloc({required this._statements, required this.connectionId, this._newRunId = newQueryId})
    : super(const RowCountIdle()) {
    on<RowCountRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('RowCountBloc');

  final IStatementRepository _statements;
  final String Function() _newRunId;

  /// The connection, from the page's route.
  final String connectionId;

  Future<void> _onRequested(RowCountRequested event, Emitter<RowCountState> emit) async {
    emit(
      RowCountRunning(
        previous: switch (state) {
          RowCountLoaded(:final count) => count,
          RowCountRunning(:final previous) => previous,
          RowCountIdle() || RowCountFailure() => null,
        },
      ),
    );
    final result = await _statements.run(
      connectionId,
      event.statement.statement,
      queryId: _newRunId(),
      catalog: event.statement.catalog,
    );
    if (emit.isDone) return;
    switch (result) {
      case Failure(:final error):
        _log.warn('count not read: {}', [error.code ?? error.runtimeType]);
        emit(RowCountFailure(error));
      case Success(:final data):
        try {
          emit(RowCountLoaded(readRowCount(data)));
        } on FormatException catch (e) {
          _log.warn('count answer not readable: {}', [e.message]);
          emit(RowCountFailure(ServerError(e.message, code: AppErrorCode.studioUnreadableAnswer.key)));
        }
    }
  }
}
