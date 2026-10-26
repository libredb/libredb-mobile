import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/onboarding/data/repositories/adoption_figures_asset.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';

/// Reads the adoption figures the onboarding shows from the asset `scripts/generate_adoption.sh` committed.
///
/// The app opens no connection for them: the script runs where a maintainer is already authenticated against the
/// private `libredb-adoption` repository, and what ships is the committed JSON. So the only failures this has to
/// survive are a missing or malformed asset — and both fall back rather than throw, because onboarding runs before
/// the user has chosen anything and "0 engines" reaches them as a claim about the product.
void main() {
  test('reads the committed asset', () async {
    final figures = await const AdoptionFiguresAsset().read();

    expect(figures.isFallback, isFalse, reason: 'the committed asset must parse, not fall back');
    expect(figures.engines, greaterThan(0));
    expect(figures.channels, greaterThan(0));
    expect(figures.listings, greaterThan(0));
  });

  test('falls back when the asset is not there, rather than throwing', () async {
    const missing = AdoptionFiguresAsset(path: 'assets/does_not_exist.json');

    expect(await missing.read(), AdoptionFigures.fallback);
  });

  test('falls back when the asset is not the shape it expects', () async {
    // NOTICE ships as an asset and is not JSON, so it stands in for a truncated or replaced file.
    const notJson = AdoptionFiguresAsset(path: 'NOTICE');

    expect(await notJson.read(), AdoptionFigures.fallback);
  });
}
