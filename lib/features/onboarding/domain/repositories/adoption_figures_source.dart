import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';

/// Where the onboarding's adoption figures come from.
///
/// They are baked in at build time, so an implementation opens no connection: `scripts/generate_adoption.sh` runs
/// where a maintainer is already authenticated against the private `libredb-adoption` repository, and what ships is
/// the committed JSON.
abstract class IAdoptionFiguresSource {
  /// The figures to show, or [AdoptionFigures.fallback] when they cannot be read.
  ///
  /// It never throws. Onboarding runs before the user has signed in or chosen anything, and a figure of zero reaches
  /// them as a claim about the product, so every failure collapses into the committed values instead.
  Future<AdoptionFigures> read();
}
