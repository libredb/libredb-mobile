import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/revoke_grant_usecase.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'revoke_grant_event.dart';
part 'revoke_grant_state.dart';

/// Revokes one grant of a connection at a time.
///
/// A revoke confirmed while another runs is dropped, so a double tap sends one `DELETE`; the page disables every row's
/// actions while one runs, so no revoke of a second row is dropped unseen.
class RevokeGrantBloc extends Bloc<RevokeGrantEvent, RevokeGrantState> {
  RevokeGrantBloc({required this._revokeGrantUseCase}) : super(const RevokeGrantIdle()) {
    on<RevokeGrantConfirmed>(_onConfirmed, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('RevokeGrantBloc');

  final RevokeGrantUseCase _revokeGrantUseCase;

  FutureOr<void> _onConfirmed(RevokeGrantConfirmed event, Emitter<RevokeGrantState> emit) async {
    emit(RevokeGrantInProgress(event.grantId));
    final result = await _revokeGrantUseCase(event.connectionId, event.grantId);
    switch (result) {
      case Success():
        emit(RevokeGrantSucceeded(event.grantId));
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        // Platform cannot be asked which one is gone: a grant revoked meanwhile and a connection that is gone both
        // answer 404, and the refresh that follows tells them apart.
        emit(
          errorCode == AppErrorCode.platformNotFound
              ? RevokeGrantAlreadyRemoved(event.grantId)
              : RevokeGrantFailed(event.grantId, errorCode: errorCode),
        );
        _log.warn('onConfirmed failed: {}', [error.code ?? error.runtimeType]);
    }
  }
}
