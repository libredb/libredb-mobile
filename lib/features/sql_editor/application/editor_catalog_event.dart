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

/// An open request named [catalog] as the database its statement runs in: it becomes the active database once the
/// server lists it, and nothing changes on a connection that names no database.
final class EditorCatalogOpenRequested extends EditorCatalogEvent {
  const EditorCatalogOpenRequested(this.catalog);

  final String catalog;

  @override
  List<Object?> get props => [catalog];
}
