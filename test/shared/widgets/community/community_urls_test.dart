import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/community/community_urls.dart';

/// The pages the community section links to, derived from the repository URL.
///
/// Its `CommunityUrls.of(ProjectLinks)` constructor is gone: `ProjectLinks` is `infrastructure/config/` and
/// `shared/` imports `core/` only (`test/architecture/import_guard_test.dart`). The mapping moved to the login page,
/// and `test/features/auth/presentation/pages/login_community_links_test.dart` covers it there.
void main() {
  const urls = CommunityUrls(
    repo: 'https://github.com/acme/dashboard',
    sponsor: 'https://github.com/sponsors/acme',
    docs: 'https://docs.acme.example',
  );

  test('builds the repository pages from the repository URL', () {
    expect(urls.repo, 'https://github.com/acme/dashboard');
    expect(urls.issues, 'https://github.com/acme/dashboard/issues');
    expect(urls.contributing, 'https://github.com/acme/dashboard/blob/main/CONTRIBUTING.md');
    expect(urls.translate, 'https://github.com/acme/dashboard/issues/new/choose');
  });

  test('keeps the sponsor and documentation pages as they are given, since neither is under the repository', () {
    expect(urls.sponsor, 'https://github.com/sponsors/acme');
    expect(urls.docs, 'https://docs.acme.example');
  });
}
