part of 'editor_catalog_bloc.dart';

sealed class EditorCatalogEvent extends Equatable {
  const EditorCatalogEvent();

  @override
  List<Object?> get props => const [];
}

/// Read the engine and, on a server-level connection, its databases: when the editor opens, and on a retry.
final class EditorCatalogRequested extends EditorCatalogEvent {
  const EditorCatalogRequested();
}
