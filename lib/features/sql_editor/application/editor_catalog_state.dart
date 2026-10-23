part of 'editor_catalog_bloc.dart';

/// Where the SQL editor runs statements on its connection. [label] is the engine's own word for a database
/// (`ContainerLevel.label` of the top level), null when Studio sends none.
sealed class EditorCatalogState extends Equatable {
  const EditorCatalogState();

  /// The database a Run sends, given [active], the active database of the connection: [active] once the databases are
  /// listed, null on a connection that names none.
  String? catalogToSend(String? active) => switch (this) {
    EditorCatalogListed() => active,
    EditorCatalogChecking() ||
    EditorCatalogMetaFailure() ||
    EditorCatalogNotUsed() ||
    EditorCatalogLoading() ||
    EditorCatalogFailure() => null,
  };

  /// Whether Run waits: until the engine is read, since a server-level connection refuses a statement that names no
  /// database, while the databases are read or could not be, and while none is active once they are listed.
  bool withholdsRun(String? active) => switch (this) {
    EditorCatalogListed() => active == null,
    EditorCatalogChecking() || EditorCatalogMetaFailure() || EditorCatalogLoading() || EditorCatalogFailure() => true,
    EditorCatalogNotUsed() => false,
  };

  @override
  List<Object?> get props => const [];
}

/// The engine is not read yet.
final class EditorCatalogChecking extends EditorCatalogState {
  const EditorCatalogChecking();
}

/// The engine could not be read, so whether it runs statements in a picked database is unknown; [error] is shown by
/// `StudioErrorBanner` with a retry.
final class EditorCatalogMetaFailure extends EditorCatalogState {
  const EditorCatalogMetaFailure({required this.error});

  final AppError error;

  @override
  List<Object?> get props => [error];

  @override
  String toString() => 'EditorCatalogMetaFailure(${error.code})';
}

/// The engine declares no `catalogSessions`: every statement runs in the connection's own database and names none.
final class EditorCatalogNotUsed extends EditorCatalogState {
  const EditorCatalogNotUsed();
}

final class EditorCatalogLoading extends EditorCatalogState {
  const EditorCatalogLoading({this.label});

  final String? label;

  @override
  List<Object?> get props => [label];
}

/// The server's databases could not be read; [error] is shown by `StudioErrorBanner` with a retry.
final class EditorCatalogFailure extends EditorCatalogState {
  const EditorCatalogFailure({required this.error, this.label});

  final AppError error;
  final String? label;

  @override
  List<Object?> get props => [error, label];

  @override
  String toString() => 'EditorCatalogFailure(${error.code})';
}

/// The databases the server lists, in Studio's order, none when it lists none.
final class EditorCatalogListed extends EditorCatalogState {
  const EditorCatalogListed({required this.catalogs, this.label});

  final List<String> catalogs;
  final String? label;

  @override
  List<Object?> get props => [catalogs, label];
}
