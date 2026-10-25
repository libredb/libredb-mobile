import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/list_connection_grants_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'grant_list_event.dart';
part 'grant_list_state.dart';

/// The grants of one connection in Platform mode.
///
/// It loads when the page opens and on a retry, and refreshes on a pull, after a revoke and after a grant is saved. A
/// newer load or refresh replaces one still running, so a late answer never overwrites a newer one.
class GrantListBloc extends Bloc<GrantListEvent, GrantListState> {
  GrantListBloc({required this._listConnectionGrantsUseCase}) : super(const GrantListInitial()) {
    on<GrantListEvent>(_onEvent, transformer: EventTransformers.restart());
  }

  static final _log = AppLogger.getLogger('GrantListBloc');

  final ListConnectionGrantsUseCase _listConnectionGrantsUseCase;

  /// The connection of the last load, which a refresh asks about again; null before the first load.
  String? _connectionId;

  FutureOr<void> _onEvent(GrantListEvent event, Emitter<GrantListState> emit) async {
    final connectionId = switch (event) {
      GrantListLoadRequested(:final connectionId) => connectionId,
      GrantListRefreshRequested() => _connectionId,
    };
    if (connectionId == null) {
      _log.debug('onEvent: a refresh before any load is ignored');
      return;
    }
    _connectionId = connectionId;

    final current = state;
    if (event is GrantListRefreshRequested && current is GrantListLoaded) {
      emit(GrantListLoaded(grants: current.grants, isRefreshing: true));
    } else {
      emit(const GrantListLoading());
    }

    final result = await _listConnectionGrantsUseCase(connectionId);
    if (emit.isDone) return;
    switch (result) {
      case Success(:final data):
        emit(GrantListLoaded(grants: data));
        _log.debug('onEvent: {} grants', [data.length]);
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        switch (state) {
          // A connection that is gone has no grants to keep on screen.
          case final GrantListLoaded loaded when errorCode != AppErrorCode.platformNotFound:
            emit(GrantListLoaded(grants: loaded.grants, refreshError: errorCode));
          case GrantListLoaded() || GrantListInitial() || GrantListLoading() || GrantListFailure():
            emit(GrantListFailure(errorCode: errorCode));
        }
        // The code only: Platform's message can name a user.
        _log.warn('onEvent failed: {}', [error.code ?? error.runtimeType]);
    }
  }
}
