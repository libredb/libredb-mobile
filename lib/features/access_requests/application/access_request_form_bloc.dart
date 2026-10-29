import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/application/requestable_connection_rules.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/create_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_requestable_connections_usecase.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

export 'package:libredb_mobile/features/access_requests/application/requestable_connection_rules.dart';

part 'access_request_form_event.dart';
part 'access_request_form_state.dart';

/// The longest reason Platform takes, in characters after trimming.
const accessRequestReasonMaxLength = 500;

/// The request form: the connections the user may ask for, and the draft they write.
///
/// The draft (connection, level, reason) stays in [AccessRequestFormReady] while a request is out and after a refusal,
/// so the form keeps what the user wrote. A Send while one is out is dropped, and a failed request is only sent again
/// when the user sends again.
class AccessRequestFormBloc extends Bloc<AccessRequestFormEvent, AccessRequestFormState> {
  AccessRequestFormBloc({required this._listRequestableConnectionsUseCase, required this._createAccessRequestUseCase})
    : super(const AccessRequestFormLoading()) {
    on<AccessRequestFormLoadRequested>(_onLoad, transformer: EventTransformers.restart());
    on<AccessRequestFormConnectionPicked>(_onConnectionPicked);
    on<AccessRequestFormLevelPicked>(_onLevelPicked);
    on<AccessRequestFormReasonChanged>(_onReasonChanged);
    on<AccessRequestFormSendRequested>(_onSubmitted, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('AccessRequestFormBloc');

  final ListRequestableConnectionsUseCase _listRequestableConnectionsUseCase;
  final CreateAccessRequestUseCase _createAccessRequestUseCase;

  FutureOr<void> _onLoad(AccessRequestFormLoadRequested event, Emitter<AccessRequestFormState> emit) async {
    emit(const AccessRequestFormLoading());
    final result = await _listRequestableConnectionsUseCase();
    if (emit.isDone) return;
    switch (result) {
      case Success(:final data):
        emit(AccessRequestFormReady(connections: data));
        _log.debug('onLoad: {} connections', [data.length]);
      case Failure(:final error):
        emit(AccessRequestFormLoadFailure(errorCode: AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic));
        _log.warn('onLoad failed: {}', [error.code ?? error.runtimeType]);
    }
  }

  /// The state to edit: Ready and with no request out; null otherwise, where an edit is ignored.
  AccessRequestFormReady? get _editable => switch (state) {
    final AccessRequestFormReady ready when ready.submission is! SubmissionSending => ready,
    _ => null,
  };

  void _onConnectionPicked(AccessRequestFormConnectionPicked event, Emitter<AccessRequestFormState> emit) {
    final ready = _editable;
    if (ready == null) return;
    final connection = ready.connections.where((c) => c.id == event.connectionId).firstOrNull;
    if (connection == null || connection.blockedBy != null) return;
    final level = ready.level;
    emit(
      ready.copyWith(
        connectionId: event.connectionId,
        level: level != null && connection.canAskFor(level) ? level : null,
        clearLevel: level == null || !connection.canAskFor(level),
        submission: const SubmissionIdle(),
      ),
    );
  }

  void _onLevelPicked(AccessRequestFormLevelPicked event, Emitter<AccessRequestFormState> emit) {
    final ready = _editable;
    if (ready == null) return;
    final connection = ready.connection;
    if (connection != null && !connection.canAskFor(event.level)) return;
    emit(ready.copyWith(level: event.level, submission: const SubmissionIdle()));
  }

  void _onReasonChanged(AccessRequestFormReasonChanged event, Emitter<AccessRequestFormState> emit) {
    final ready = _editable;
    if (ready == null) return;
    emit(ready.copyWith(reason: event.reason, submission: const SubmissionIdle()));
  }

  FutureOr<void> _onSubmitted(AccessRequestFormSendRequested event, Emitter<AccessRequestFormState> emit) async {
    final ready = _editable;
    if (ready == null) return;
    final connectionId = ready.connectionId;
    final level = ready.level;
    final reason = ready.reason.trim();
    final missing = {
      if (connectionId == null) AccessRequestField.connection,
      if (level == null) AccessRequestField.level,
      if (reason.isEmpty || reason.length > accessRequestReasonMaxLength) AccessRequestField.reason,
    };
    if (missing.isNotEmpty) {
      emit(ready.copyWith(submission: SubmissionIncomplete(missing)));
      return;
    }

    emit(ready.copyWith(submission: const SubmissionSending()));
    final result = await _createAccessRequestUseCase(connectionId: connectionId!, level: level!, reason: ready.reason);
    switch (result) {
      case Success(:final data):
        emit(AccessRequestFormSubmitted(data));
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        final field = switch (errorCode) {
          AppErrorCode.platformAccessRequestReasonRefused => AccessRequestField.reason,
          AppErrorCode.platformGrantLevelRefused => AccessRequestField.level,
          _ => null,
        };
        emit(
          ready.copyWith(
            submission: SubmissionRefused(errorCode: errorCode, field: field),
          ),
        );
        // The code only: Platform's message can carry a reason or a connection name.
        _log.warn('onSubmitted failed: {}', [error.code ?? error.runtimeType]);
    }
  }
}
