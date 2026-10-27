/// The pages the community section links to: the repository and the pages in it, and the sponsor and documentation
/// pages.
///
/// It takes three plain strings and derives the rest, rather than reading them from `ProjectLinks`. `ProjectLinks`
/// lives under `infrastructure/config/`, and `shared/` imports `core/` only — so the mapping belongs to the caller,
/// under `features/`, where that import is legal (`test/architecture/import_guard_test.dart`).
class CommunityUrls {
  const CommunityUrls({required this.repo, required this.sponsor, required this.docs});

  /// The repository, such as `https://github.com/libredb/libredb-mobile`, without a trailing `/`.
  final String repo;
  final String sponsor;
  final String docs;

  String get issues => '$repo/issues';
  String get contributing => '$repo/blob/main/CONTRIBUTING.md';

  /// Translations come in as issues, as CONTRIBUTING.md asks, so this opens the issue form chooser.
  String get translate => '$repo/issues/new/choose';
}
