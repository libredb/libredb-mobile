import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'remove_my_data_event.dart';
part 'remove_my_data_state.dart';

/// The user's 'Remove my data': clears every store of [UserDataRegistry] for the signed-in account. The page signs out
/// once it is done, and stays signed in with a retry when a store failed.
class RemoveMyDataBloc extends Bloc<RemoveMyDataEvent, RemoveMyDataState> {
  RemoveMyDataBloc({required this._registry}) : super(const RemoveMyDataIdle()) {
    // A second tap while the stores are clearing would clear them twice and sign out twice.
    on<RemoveMyDataRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('RemoveMyDataBloc');

  final UserDataRegistry _registry;

  /// Tries every store even when one fails, so a failure leaves as little as it can; the log names the store and the
  /// error type only, since an error text could carry a stored value.
  Future<void> _onRequested(RemoveMyDataRequested event, Emitter<RemoveMyDataState> emit) async {
    emit(const RemoveMyDataInProgress());
    final failed = <String>[];
    for (final store in _registry.stores) {
      try {
        await store.clear(event.subject);
      } catch (e) {
        failed.add(store.name);
        _log.error('Could not clear {}: {}', [store.name, e.runtimeType]);
      }
    }
    if (failed.isEmpty) {
      _log.info('Removed the data of the signed-in account from {} stores', [_registry.stores.length]);
      emit(const RemoveMyDataDone());
    } else {
      emit(const RemoveMyDataFailure(errorCode: AppErrorCode.settingsUserDataNotRemoved));
    }
  }
}
