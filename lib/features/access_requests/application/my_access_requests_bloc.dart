import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_my_access_requests_usecase.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'my_access_requests_event.dart';
part 'my_access_requests_state.dart';

/// The signed-in Studio user's own access requests.
///
/// A load or a refresh replaces one still running, so a late answer never overwrites a newer one. A refresh while a
/// list is shown keeps it on screen until the answer. [MyAccessRequestReplaced] swaps one row without asking Platform.
class MyAccessRequestsBloc extends Bloc<MyAccessRequestsEvent, MyAccessRequestsState> {
  MyAccessRequestsBloc({required this._listMyAccessRequestsUseCase}) : super(const MyAccessRequestsInitial()) {
    on<MyAccessRequestsFetchEvent>(_onFetch, transformer: EventTransformers.restart());
    on<MyAccessRequestReplaced>(_onReplaced);
  }

  static final _log = AppLogger.getLogger('MyAccessRequestsBloc');

  final ListMyAccessRequestsUseCase _listMyAccessRequestsUseCase;

  FutureOr<void> _onFetch(MyAccessRequestsFetchEvent event, Emitter<MyAccessRequestsState> emit) async {
    final current = state;
    if (event is MyAccessRequestsRefreshRequested && current is MyAccessRequestsLoaded) {
      emit(MyAccessRequestsLoaded(requests: current.requests, isRefreshing: true));
    } else {
      emit(const MyAccessRequestsLoading());
    }

    final result = await _listMyAccessRequestsUseCase();
    if (emit.isDone) return;
    switch (result) {
      case Success(:final data):
        emit(MyAccessRequestsLoaded(requests: data));
        _log.debug('onFetch: {} requests', [data.length]);
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        switch (state) {
          case final MyAccessRequestsLoaded loaded:
            emit(MyAccessRequestsLoaded(requests: loaded.requests, refreshError: errorCode));
          case MyAccessRequestsInitial() || MyAccessRequestsLoading() || MyAccessRequestsFailure():
            emit(MyAccessRequestsFailure(errorCode: errorCode));
        }
        // The code only: Platform's message can carry a reason or a connection name.
        _log.warn('onFetch failed: {}', [error.code ?? error.runtimeType]);
    }
  }

  void _onReplaced(MyAccessRequestReplaced event, Emitter<MyAccessRequestsState> emit) {
    final current = state;
    if (current is! MyAccessRequestsLoaded) return;
    emit(
      MyAccessRequestsLoaded(
        requests: [for (final request in current.requests) request.id == event.request.id ? event.request : request],
        isRefreshing: current.isRefreshing,
        refreshError: current.refreshError,
      ),
    );
  }
}
