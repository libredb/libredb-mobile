import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/utils/search_fold.dart';

void main() {
  group('foldForSearch', () {
    test('lowers ASCII letters', () {
      expect(foldForSearch('Sales DB'), 'sales db');
    });

    test('folds the dotted capital I to a plain i, as Studio does', () {
      expect(foldForSearch('İstanbul'), 'istanbul');
    });

    test('folds the dotless i to a plain i as well, a deliberate superset of Studio', () {
      expect(foldForSearch('Kırıkkale'), 'kirikkale');
      expect(foldForSearch('ILIK'), 'ilik');
    });

    test('keeps the length of the text, so a match range stays valid in the label', () {
      for (final text in ['İSTANBUL', 'ılık', 'Iİıi', 'Straße', 'Ünye']) {
        expect(foldForSearch(text).length, text.length, reason: text);
      }
    });

    test('keeps a written i with a combining dot as it is', () {
      expect(foldForSearch('i̇'), 'i̇');
    });
  });

  group('normalizeSearchQuery', () {
    test('trims and folds', () {
      expect(normalizeSearchQuery('  İzmir '), 'izmir');
    });

    test('is empty for whitespace alone, which means no filter', () {
      expect(normalizeSearchQuery('   '), isEmpty);
    });
  });

  group('matchesSearch', () {
    test('matches when any field holds the query, whatever the case and the Turkish i', () {
      expect(matchesSearch('istanbul', ['Main', null, 'db.İSTANBUL.internal']), isTrue);
      expect(matchesSearch('kirik', ['KIRIKKALE']), isTrue);
      expect(matchesSearch('ıstan', ['Istanbul']), isTrue);
    });

    test('does not match when no field holds the query', () {
      expect(matchesSearch('ankara', ['Istanbul', null]), isFalse);
    });

    test('matches everything for an empty query', () {
      expect(matchesSearch('', [null]), isTrue);
    });
  });
}
