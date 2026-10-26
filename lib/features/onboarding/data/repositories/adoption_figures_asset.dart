import 'package:flutter/services.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/onboarding/domain/repositories/adoption_figures_source.dart';
import 'package:libredb_mobile/shared/adoption/adoption_figures.dart';

/// [IAdoptionFiguresSource] over the asset `scripts/generate_adoption.sh` writes and commits.
class AdoptionFiguresAsset implements IAdoptionFiguresSource {
  const AdoptionFiguresAsset({this.path = defaultPath});

  /// Where the script writes, and what `pubspec.yaml` declares.
  static const String defaultPath = 'assets/adoption.json';

  static final _log = AppLogger.getLogger('AdoptionFiguresAsset');

  /// The asset to read; a test points this elsewhere to exercise a missing or malformed one.
  final String path;

  @override
  Future<AdoptionFigures> read() async {
    try {
      return AdoptionFigures.parse(await rootBundle.loadString(path));
    } catch (error) {
      // The bundle can fail to deliver an asset, and onboarding has to go on: it runs before the user has signed in
      // or chosen anything, so there is nothing to retry and nobody to tell.
      _log.warn('read: {} could not be loaded, showing the figures shipped in the source: {}', [path, error]);
      return AdoptionFigures.fallback;
    }
  }
}
