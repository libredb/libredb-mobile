part of 'active_catalog_cubit.dart';

/// The database statements run in on a server-level connection.
sealed class ActiveCatalogState extends Equatable {
  const ActiveCatalogState();

  @override
  List<Object?> get props => const [];
}

/// No database is active.
final class ActiveCatalogNone extends ActiveCatalogState {
  const ActiveCatalogNone();
}

/// [catalog] is the active database of [connectionId].
final class ActiveCatalogChosen extends ActiveCatalogState {
  const ActiveCatalogChosen({required this.connectionId, required this.catalog});

  final String connectionId;
  final String catalog;

  @override
  List<Object?> get props => [connectionId, catalog];
}
