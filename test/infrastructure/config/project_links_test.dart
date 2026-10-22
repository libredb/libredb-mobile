import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectLinks', () {
    test('links to the LibreDB Mobile repository, its documentation and the LibreDB sponsor page', () {
      const links = ProjectLinks();

      expect(links.repositoryUrl, 'https://github.com/libredb/libredb-mobile');
      expect(links.docsUrl, 'https://github.com/libredb/libredb-mobile/tree/main/docs');
      expect(links.sponsorUrl, 'https://github.com/sponsors/libredb');
    });

    test('gives the links it is given', () {
      const links = ProjectLinks(
        repository: 'https://github.com/acme/dashboard',
        docs: 'https://docs.acme.example',
        sponsor: 'https://github.com/sponsors/acme',
      );

      expect(links.repositoryUrl, 'https://github.com/acme/dashboard');
      expect(links.docsUrl, 'https://docs.acme.example');
      expect(links.sponsorUrl, 'https://github.com/sponsors/acme');
    });
  });
}
