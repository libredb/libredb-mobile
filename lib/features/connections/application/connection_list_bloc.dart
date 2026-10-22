import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/connection_sections.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';
import 'package:libredb_mobile/shared/utils/search_fold.dart';

part 'connection_list_event.dart';
part 'connection_list_state.dart';

class ConnectionListBloc extends Bloc<ConnectionListEvent, ConnectionListState> {
  ConnectionListBloc({required this._listManagedConnectionsUseCase}) : super(const ConnectionListInitial()) {
    on<ConnectionListLoadEvent>(_onLoad, transformer: EventTransformers.restart());
    on<ConnectionListSearchChanged>(
      _onSearchChanged,
      transformer: EventTransformers.debounceRestartable(searchDebounce),
    );
    on<ConnectionListEnvironmentFilterChanged>(_onEnvironmentFilterChanged);
  }

  /// How long the search waits after a keystroke before it narrows the list.
  static const searchDebounce = Duration(milliseconds: 200);

  static final _log = AppLogger.getLogger('ConnectionListBloc');
  final ListManagedConnectionsUseCase _listManagedConnectionsUseCase;

  /// The search and the filter chosen before a list arrived, applied once it does.
  String _query = '';
  String? _environment;

  FutureOr<void> _onLoad(ConnectionListLoadEvent event, Emitter<ConnectionListState> emit) async {
    _log.debug('BEGIN: onLoad {}', [event.runtimeType]);
    final previous = switch ((event, state)) {
      (ConnectionListRefreshed(), final ConnectionListLoaded loaded) => loaded,
      _ => null,
    };
    emit(previous == null ? const ConnectionListLoading() : previous._with(isRefreshing: true));
    final result = await _listManagedConnectionsUseCase();
    switch (result) {
      case Success(:final data):
        emit(
          ConnectionListLoaded(
            connections: data.connections,
            cacheHint: data.cacheHint,
            query: _query,
            environment: _environment,
          ),
        );
        _log.debug('END: onLoad connections: {}', [data.connections.length]);
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        // A failed refresh starts from the current state, not from [previous], so a search or a filter chosen while
        // Studio was answering stays applied.
        emit(
          previous == null
              ? ConnectionListFailure(errorCode: errorCode)
              : (state as ConnectionListLoaded)._with(refreshErrorCode: errorCode),
        );
        _log.error('END: onLoad error: {}', [error.message]);
    }
  }

  void _onSearchChanged(ConnectionListSearchChanged event, Emitter<ConnectionListState> emit) {
    _query = event.query;
    if (state case final ConnectionListLoaded loaded) {
      emit(loaded._with(query: event.query, isRefreshing: loaded.isRefreshing));
    }
  }

  void _onEnvironmentFilterChanged(ConnectionListEnvironmentFilterChanged event, Emitter<ConnectionListState> emit) {
    _environment = event.environment;
    if (state case final ConnectionListLoaded loaded) {
      emit(loaded._with(environment: () => event.environment, isRefreshing: loaded.isRefreshing));
    }
  }
}
