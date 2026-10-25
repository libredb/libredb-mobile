import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_connections/application/usecases/set_connection_active_usecase.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'platform_connection_active_event.dart';
part 'platform_connection_active_state.dart';

/// Enables or disables one connection of the install at a time.
///
/// A request confirmed while another runs is dropped, so a double confirm sends one `PATCH`; the page disables every
/// row's menu while one runs, so no request on a second row is dropped unseen. Nothing is retried.
class PlatformConnectionActiveBloc extends Bloc<PlatformConnectionActiveEvent, PlatformConnectionActiveState> {
  PlatformConnectionActiveBloc({required this._setConnectionActiveUseCase})
    : super(const PlatformConnectionActiveIdle()) {
    on<PlatformConnectionActiveRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('PlatformConnectionActiveBloc');

  final SetPlatformConnectionActiveUseCase _setConnectionActiveUseCase;

  FutureOr<void> _onRequested(
    PlatformConnectionActiveRequested event,
    Emitter<PlatformConnectionActiveState> emit,
  ) async {
    emit(PlatformConnectionActiveInProgress(event.id));
    final result = await _setConnectionActiveUseCase(event.id, active: event.active);
    switch (result) {
      case Success(:final data):
        emit(PlatformConnectionActiveSucceeded(data));
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        emit(
          errorCode == AppErrorCode.platformNotFound
              ? PlatformConnectionActiveGone(event.id)
              : PlatformConnectionActiveFailed(event.id, errorCode: errorCode),
        );
        // The code only: Platform's message can name a user or the connection.
        _log.warn('onRequested failed: {}', [error.code ?? error.runtimeType]);
    }
  }
}
