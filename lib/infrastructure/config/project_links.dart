/// LibreDB Mobile's own pages that the app links to: its source repository, its documentation and its sponsor page.
///
/// A test that needs other values passes its own through `AppDependencies`.
final class ProjectLinks {
  const ProjectLinks({
    this._repository = 'https://github.com/libredb/libredb-mobile',
    this._docs = 'https://github.com/libredb/libredb-mobile/tree/main/docs',
    this._sponsor = 'https://github.com/sponsors/libredb',
  });

  final String _repository;
  final String _docs;
  final String _sponsor;

  /// The source repository, without a trailing `/`.
  String get repositoryUrl => _repository;

  /// The documentation.
  String get docsUrl => _docs;

  /// The page that takes sponsorships.
  String get sponsorUrl => _sponsor;
}
