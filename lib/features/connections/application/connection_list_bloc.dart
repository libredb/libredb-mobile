import 'dart:async';

import 'package:clock/clock.dart';
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

  /// The last list Studio answered, which an offline load keeps on screen even when it restarted another load.
  ConnectionListLoaded? _lastLoaded;

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
        final loaded = ConnectionListLoaded(
          connections: data.connections,
          cacheHint: data.cacheHint,
          loadedAt: clock.now(),
          query: _query,
          environment: _environment,
        );
        _lastLoaded = loaded;
        emit(loaded);
        _log.debug('END: onLoad connections: {}', [data.connections.length]);
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        // A request refused because the device is offline never reached Studio, so what was loaded stays on screen,
        // marked stale by the page, instead of turning into an error; the search and the filter chosen meanwhile stay.
        final kept = _lastLoaded;
        if (errorCode == AppErrorCode.networkOffline && kept != null) {
          emit(kept._with(query: _query, environment: () => _environment));
          _log.info('END: onLoad offline, keeping the {} connections loaded before', [kept.connections.length]);
          return;
        }
        if (previous == null) {
          // Studio refused or failed the list, so the rows loaded before are no longer shown and are not brought back.
          _lastLoaded = null;
          emit(ConnectionListFailure(errorCode: errorCode));
        } else {
          // A failed refresh starts from the current state, not from [previous], so a search or a filter chosen while
          // Studio was answering stays applied.
          emit((state as ConnectionListLoaded)._with(refreshErrorCode: errorCode));
        }
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
