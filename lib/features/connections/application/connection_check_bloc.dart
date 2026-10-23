import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'connection_check_event.dart';
part 'connection_check_state.dart';

/// Checks one connection when the user asks: `POST /api/db/test-connection`, which spends a slot of the user's Studio
/// request budget and opens a connection to the database.
///
/// Like Studio, it never checks a connection whose engine resumes billed compute unless the user asks for it anyway.
/// The engine is read through [IProviderMetaRepository], whose cache usually answers without a request.
class ConnectionCheckBloc extends Bloc<ConnectionCheckEvent, ConnectionCheckState> {
  ConnectionCheckBloc({
    required this.connectionId,
    required this._connectionRepository,
    required this._providerMetaRepository,
  }) : super(const ConnectionCheckIdle()) {
    on<ConnectionCheckEvent>(_onCheck, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('ConnectionCheckBloc');

  /// The connection to check, `seed:<id>`.
  final String connectionId;
  final IConnectionRepository _connectionRepository;
  final IProviderMetaRepository _providerMetaRepository;

  /// Whether the user chose Check anyway in this sheet, so a later check does not ask again.
  bool _billedComputeAccepted = false;

  Future<void> _onCheck(ConnectionCheckEvent event, Emitter<ConnectionCheckState> emit) async {
    _log.debug('BEGIN: onCheck {}', [event.runtimeType]);
    emit(const ConnectionCheckChecking());
    if (event is ConnectionCheckForced) _billedComputeAccepted = true;
    if (!_billedComputeAccepted) {
      switch (await _providerMetaRepository.providerMeta(connectionId)) {
        case Failure(:final error):
          _log.warn('END: onCheck provider-meta failed: {}', [error.code ?? error.runtimeType]);
          emit(ConnectionCheckFailed(error: error));
          return;
        case Success(:final data) when data.resumesBilledCompute:
          _log.debug('END: onCheck not checked, the engine resumes billed compute');
          emit(const ConnectionCheckNotChecked());
          return;
        case Success():
          break;
      }
    }
    switch (await _connectionRepository.test(connectionId)) {
      case Success(:final data) when data.degraded:
        emit(ConnectionCheckDegraded(message: data.message, warnings: data.warnings));
        _log.debug('END: onCheck degraded, warnings: {}', [data.warnings.length]);
      case Success(:final data):
        emit(ConnectionCheckOnline(latency: data.latency, warnings: data.warnings));
        _log.debug('END: onCheck online, latency: {}, warnings: {}', [data.latency, data.warnings.length]);
      case Failure(:final error):
        // The error text may be the database's own words, so only its code is logged.
        emit(ConnectionCheckFailed(error: error));
        _log.warn('END: onCheck failed: {}', [error.code ?? error.runtimeType]);
    }
  }
}
