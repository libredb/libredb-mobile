import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';

/// Whether results show cards or a table, the device setting every result view follows.
///
/// It shows cards until [restore] reads the stored mode, and stays on cards, with one warn line, when that cannot be
/// read. A choice the device refuses to store still applies until the app closes.
///
/// A Cubit, not a Bloc: restoring and choosing are single calls with nothing to debounce or drop.
class ResultViewModeCubit extends Cubit<ResultViewMode> {
  ResultViewModeCubit({required this._store}) : super(ResultViewMode.cards);

  static final _log = AppLogger.getLogger('ResultViewModeCubit');

  final IResultViewModeStore _store;

  /// Whether the user chose a mode, which a stored one read later never replaces.
  bool _chosen = false;

  /// Shows the stored mode, if the device stored one.
  Future<void> restore() async {
    final ResultViewMode? stored;
    try {
      stored = await _store.read();
    } catch (e) {
      _log.warn('the stored result view mode cannot be read, showing cards: {}', [e.runtimeType]);
      return;
    }
    if (isClosed || _chosen || stored == null) return;
    emit(stored);
  }

  /// Shows [mode], the user's choice, and stores it for the device.
  Future<void> select(ResultViewMode mode) async {
    _chosen = true;
    emit(mode);
    try {
      await _store.write(mode);
    } catch (e) {
      _log.warn('the result view mode was not stored, it applies until the app closes: {}', [e.runtimeType]);
    }
  }
}
