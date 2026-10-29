import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/withdraw_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'withdraw_access_request_event.dart';
part 'withdraw_access_request_state.dart';

/// Withdraws one pending request at a time.
///
/// A withdraw asked for while another runs is dropped, so a double tap sends one `POST`; the page disables every row's
/// Withdraw while one runs, so no second row is dropped unseen. A failed withdraw is never sent again by itself.
class WithdrawAccessRequestBloc extends Bloc<WithdrawAccessRequestEvent, WithdrawAccessRequestState> {
  WithdrawAccessRequestBloc({required this._withdrawAccessRequestUseCase}) : super(const WithdrawAccessRequestIdle()) {
    on<WithdrawAccessRequestRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('WithdrawAccessRequestBloc');

  final WithdrawAccessRequestUseCase _withdrawAccessRequestUseCase;

  FutureOr<void> _onRequested(WithdrawAccessRequestRequested event, Emitter<WithdrawAccessRequestState> emit) async {
    emit(WithdrawAccessRequestInProgress(event.requestId));
    final result = await _withdrawAccessRequestUseCase(event.requestId);
    switch (result) {
      case Success(:final data):
        emit(WithdrawAccessRequestDone(data));
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        emit(WithdrawAccessRequestFailed(event.requestId, errorCode: errorCode));
        // The code only: Platform's message can carry a reason or a connection name.
        _log.warn('onRequested failed: {}', [error.code ?? error.runtimeType]);
    }
  }
}
