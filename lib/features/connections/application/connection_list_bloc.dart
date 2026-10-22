import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_advance/core/errors/app_error_code.dart';
import 'package:flutter_bloc_advance/core/logging/app_logger.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/studio_connection.dart';
import 'package:flutter_bloc_advance/shared/utils/event_transformers.dart';

part 'connection_list_event.dart';
part 'connection_list_state.dart';

class ConnectionListBloc extends Bloc<ConnectionListEvent, ConnectionListState> {
  ConnectionListBloc({required this._listManagedConnectionsUseCase}) : super(const ConnectionListInitial()) {
    on<ConnectionListRequested>(_onRequested, transformer: EventTransformers.restart());
  }

  static final _log = AppLogger.getLogger('ConnectionListBloc');
  final ListManagedConnectionsUseCase _listManagedConnectionsUseCase;

  FutureOr<void> _onRequested(ConnectionListRequested event, Emitter<ConnectionListState> emit) async {
    _log.debug('BEGIN: onRequested');
    emit(const ConnectionListLoading());
    final result = await _listManagedConnectionsUseCase();
    switch (result) {
      case Success(:final data):
        emit(ConnectionListLoaded(connections: data));
        _log.debug('END: onRequested connections: {}', [data.length]);
      case Failure(:final error):
        emit(ConnectionListFailure(errorCode: AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic));
        _log.error('END: onRequested error: {}', [error.message]);
    }
  }
}
