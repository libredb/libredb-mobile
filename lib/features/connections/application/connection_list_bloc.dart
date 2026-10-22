import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

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
        emit(ConnectionListLoaded(connections: data.connections, cacheHint: data.cacheHint));
        _log.debug('END: onRequested connections: {}', [data.connections.length]);
      case Failure(:final error):
        emit(ConnectionListFailure(errorCode: AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic));
        _log.error('END: onRequested error: {}', [error.message]);
    }
  }
}
