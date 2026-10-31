import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';

/// The sections of the connection list the user collapsed, kept on the device as a convenience only: a stored state
/// that cannot be read means every section is expanded, and a change the device refuses to store still applies on
/// screen.
///
/// A Cubit, not a Bloc: its repository is this device's storage and not a server, and a tap applies on screen
/// whatever that storage answers, so there is nothing to debounce, drop or replay.
class CollapsedSectionsCubit extends Cubit<CollapsedSectionsState> {
  CollapsedSectionsCubit({required this._repository}) : super(const CollapsedSectionsState());

  static final _log = AppLogger.getLogger('CollapsedSectionsCubit');

  final ICollapsedSectionsRepository _repository;

  /// Whether the user changed a section since the cubit was made, so a stored state read later does not undo it.
  bool _changed = false;

  Future<void> restore() async {
    final Set<String> stored;
    try {
      stored = await _repository.read();
    } catch (e) {
      _log.warn('restore failed, every section stays expanded: {}', [e.runtimeType]);
      return;
    }
    if (isClosed || _changed) return;
    emit(CollapsedSectionsState(stored));
  }

  /// Collapses the section [key] names, or expands it when it is collapsed, and stores the result.
  Future<void> toggle(String key) async {
    _changed = true;
    final collapsed = {...state.collapsed};
    if (!collapsed.remove(key)) collapsed.add(key);
    emit(CollapsedSectionsState(collapsed));
    try {
      await _repository.write(collapsed);
    } catch (e) {
      _log.warn('toggle not stored, it applies until the page closes: {}', [e.runtimeType]);
    }
  }
}

final class CollapsedSectionsState extends Equatable {
  const CollapsedSectionsState([this.collapsed = const {}]);

  /// The keys of the collapsed sections (`ConnectionSection.key`).
  final Set<String> collapsed;

  bool isCollapsed(String key) => collapsed.contains(key);

  @override
  List<Object?> get props => [collapsed];
}
