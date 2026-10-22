import 'dart:async';

import 'package:clock/clock.dart';
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

  /// The last list Studio answered, which an offline refresh keeps on screen even when it restarted another refresh.
  ConnectionListLoaded? _lastLoaded;

  FutureOr<void> _onRequested(ConnectionListRequested event, Emitter<ConnectionListState> emit) async {
    _log.debug('BEGIN: onRequested');
    emit(const ConnectionListLoading());
    final result = await _listManagedConnectionsUseCase();
    switch (result) {
      case Success(:final data):
        final loaded = ConnectionListLoaded(
          connections: data.connections,
          cacheHint: data.cacheHint,
          loadedAt: clock.now(),
        );
        _lastLoaded = loaded;
        emit(loaded);
        _log.debug('END: onRequested connections: {}', [data.connections.length]);
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        // A request refused because the device is offline never reached Studio, so what was loaded stays on screen,
        // marked stale by the page, instead of turning into an error.
        final previous = _lastLoaded;
        if (errorCode == AppErrorCode.networkOffline && previous != null) {
          emit(previous);
          _log.info('END: onRequested offline, keeping the {} connections loaded before', [
            previous.connections.length,
          ]);
          return;
        }
        // Studio refused or failed the list, so the rows loaded before are no longer shown and are not brought back.
        _lastLoaded = null;
        emit(ConnectionListFailure(errorCode: errorCode));
        _log.error('END: onRequested error: {}', [error.message]);
    }
  }
}
