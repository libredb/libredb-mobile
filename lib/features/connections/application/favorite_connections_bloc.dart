import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'favorite_connections_event.dart';
part 'favorite_connections_state.dart';

/// The starred and recently opened connections of the signed-in subject, kept on the device as a convenience only:
/// favorites that cannot be read leave the list without them, and a change the device refuses to store still applies
/// on screen until the app closes.
///
/// The app tells it who is signed in with [FavoriteConnectionsSubjectChanged]. Every event runs after the one before
/// it, so a star sent while the favorites are read applies to them, and never to another subject's.
class FavoriteConnectionsBloc extends Bloc<FavoriteConnectionsEvent, FavoriteConnectionsState> {
  FavoriteConnectionsBloc({required this._repository}) : super(const FavoriteConnectionsNone()) {
    on<FavoriteConnectionsEvent>(
      (event, emit) => switch (event) {
        FavoriteConnectionsSubjectChanged() => _onSubjectChanged(event, emit),
        FavoriteConnectionsReloaded() => _read(emit),
        FavoriteConnectionStarToggled() => _onStarToggled(event, emit),
        FavoriteConnectionOpened() => _onOpened(event, emit),
      },
      transformer: EventTransformers.queue(),
    );
  }

  /// How many opened connections the device keeps, more than the list shows, so a connection Studio does not list for
  /// a while leaves the others in the Recent strip.
  static const storedRecentLimit = 10;

  static final _log = AppLogger.getLogger('FavoriteConnectionsBloc');

  final IFavoriteConnectionsRepository _repository;

  /// The subject whose favorites the state holds or is reading.
  String? _subject;

  Future<void> _onSubjectChanged(
    FavoriteConnectionsSubjectChanged event,
    Emitter<FavoriteConnectionsState> emit,
  ) async {
    final subject = event.subject;
    if (subject == _subject && state is FavoriteConnectionsReady) return;
    _subject = subject;
    if (subject == null) {
      if (state is! FavoriteConnectionsNone) emit(const FavoriteConnectionsNone());
      return;
    }
    await _read(emit);
  }

  /// Reads the favorites of [_subject]; nothing while nobody is signed in.
  Future<void> _read(Emitter<FavoriteConnectionsState> emit) async {
    final subject = _subject;
    if (subject == null) return;
    emit(const FavoriteConnectionsLoading());
    try {
      emit(FavoriteConnectionsReady(await _repository.read(subject)));
    } catch (e) {
      _log.warn('read failed, the list shows no favorites: {}', [e.runtimeType]);
      emit(const FavoriteConnectionsUnavailable());
    }
  }

  Future<void> _onStarToggled(FavoriteConnectionStarToggled event, Emitter<FavoriteConnectionsState> emit) async {
    final current = _readyOrNull('star');
    if (current == null) return;
    final starred = {...current.starred};
    if (!starred.remove(event.connectionId)) starred.add(event.connectionId);
    await _store(ConnectionFavorites(starred: starred, recent: current.recent), emit);
  }

  Future<void> _onOpened(FavoriteConnectionOpened event, Emitter<FavoriteConnectionsState> emit) async {
    final current = _readyOrNull('open');
    if (current == null) return;
    final id = event.connectionId;
    if (current.recent.isNotEmpty && current.recent.first == id) return;
    final recent = [id, ...current.recent.where((other) => other != id)].take(storedRecentLimit).toList();
    await _store(ConnectionFavorites(starred: current.starred, recent: recent), emit);
  }

  /// The favorites on screen, or null, logged, when there are none to change.
  ConnectionFavorites? _readyOrNull(String change) {
    if (state case FavoriteConnectionsReady(:final favorites)) return favorites;
    _log.debug('{} ignored, no favorites are shown: {}', [change, state.runtimeType]);
    return null;
  }

  Future<void> _store(ConnectionFavorites favorites, Emitter<FavoriteConnectionsState> emit) async {
    emit(FavoriteConnectionsReady(favorites));
    try {
      await _repository.write(_subject!, favorites);
    } catch (e) {
      _log.warn('change not stored, it applies until the app closes: {}', [e.runtimeType]);
    }
  }
}
