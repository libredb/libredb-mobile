import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/application/usecases/list_connections_usecase.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';
import 'package:libredb_mobile/shared/utils/search_fold.dart';

part 'platform_connection_list_event.dart';
part 'platform_connection_list_state.dart';

/// The list of the install's connections in Platform mode, and its search.
///
/// It loads when the tab opens, on a pull to refresh and on a retry; there is no timed refresh. A newer load replaces
/// one still running, so a late answer never overwrites a newer one. A connection that was enabled or disabled takes
/// the place of its item without a reload.
class PlatformConnectionListBloc extends Bloc<PlatformConnectionListEvent, PlatformConnectionListState> {
  PlatformConnectionListBloc({required this._listPlatformConnectionsUseCase})
    : super(const PlatformConnectionListInitial()) {
    on<PlatformConnectionListLoadEvent>(_onLoad, transformer: EventTransformers.restart());
    on<PlatformConnectionListSearchChanged>(
      _onSearchChanged,
      transformer: EventTransformers.debounceRestartable(searchDebounce),
    );
    on<PlatformConnectionReplaced>(_onReplaced);
  }

  /// How long the search waits after a keystroke before it narrows the list.
  static const searchDebounce = Duration(milliseconds: 200);

  static final _log = AppLogger.getLogger('PlatformConnectionListBloc');

  final ListPlatformConnectionsUseCase _listPlatformConnectionsUseCase;

  /// The search typed so far, applied to a list that arrives after it.
  String _query = '';

  FutureOr<void> _onLoad(PlatformConnectionListLoadEvent event, Emitter<PlatformConnectionListState> emit) async {
    _log.debug('BEGIN: onLoad {}', [event.runtimeType]);
    switch (state) {
      case final PlatformConnectionListLoaded loaded:
        emit(loaded._with(isRefreshing: true));
      case PlatformConnectionListInitial() || PlatformConnectionListLoading() || PlatformConnectionListFailure():
        emit(const PlatformConnectionListLoading());
    }
    final result = await _listPlatformConnectionsUseCase();
    if (emit.isDone) return;
    switch (result) {
      case Success(:final data):
        emit(PlatformConnectionListLoaded(connections: data, query: _query));
        _log.debug('END: onLoad connections: {}', [data.length]);
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        switch (state) {
          // A failed refresh keeps the list on screen, with the error next to it.
          case final PlatformConnectionListLoaded loaded:
            emit(loaded._with(isRefreshing: false, refreshError: () => errorCode));
          case PlatformConnectionListInitial() || PlatformConnectionListLoading() || PlatformConnectionListFailure():
            emit(PlatformConnectionListFailure(errorCode: errorCode));
        }
        // The code only: Platform's message can name a user.
        _log.warn('END: onLoad failed: {}', [error.code ?? error.runtimeType]);
    }
  }

  void _onSearchChanged(PlatformConnectionListSearchChanged event, Emitter<PlatformConnectionListState> emit) {
    _query = event.query;
    switch (state) {
      case final PlatformConnectionListLoaded loaded:
        emit(loaded._with(query: event.query));
      case PlatformConnectionListInitial() || PlatformConnectionListLoading() || PlatformConnectionListFailure():
        break;
    }
  }

  void _onReplaced(PlatformConnectionReplaced event, Emitter<PlatformConnectionListState> emit) {
    switch (state) {
      case final PlatformConnectionListLoaded loaded:
        final id = event.connection.id;
        if (!loaded.connections.any((c) => c.id == id)) {
          _log.debug('onReplaced: {} is not in the list', [id]);
          return;
        }
        emit(
          loaded._with(
            connections: List.unmodifiable([for (final c in loaded.connections) c.id == id ? event.connection : c]),
          ),
        );
      case PlatformConnectionListInitial() || PlatformConnectionListLoading() || PlatformConnectionListFailure():
        break;
    }
  }
}
