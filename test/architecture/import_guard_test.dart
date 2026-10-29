import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifies architectural dependency rules from CLAUDE.md:
///
/// - `app/` → features, shared, infrastructure, core
/// - `features/` → shared, infrastructure, core (NOT other features' internals)
/// - `shared/` → core only (NO features or infrastructure imports)
/// - `core/` → nothing (NO shared, features, or infrastructure imports)
///
/// It also keeps url_launcher behind `shared/utils/external_link.dart`, so every link tells the user when it does not
/// open.
///
/// Pre-existing violations are documented as known exceptions below.
/// These should be fixed incrementally; adding NEW exceptions is discouraged.

// ---------------------------------------------------------------------------
// Known exceptions — pre-existing tech debt to fix in future phases.
// Each entry: 'relative_file_path → imported_path_fragment'
// ---------------------------------------------------------------------------

/// core/ importing infrastructure/ (security_utils needs storage for JWT)
const _knownCoreExceptions = {'lib/core/security/security_utils.dart → infrastructure/storage/local_storage'};

/// shared/ importing app/ (theme/language dialogs depend on app-level blocs)
const _knownSharedExceptions = {
  'lib/shared/widgets/brightness_selection_dialog.dart → app/theme/theme_bloc',
  'lib/shared/widgets/theme_selection_dialog.dart → app/theme/theme_bloc',
  'lib/shared/widgets/language_selection_dialog.dart → app/localization/locale_cubit',
};

/// features/ importing other features' internals. None today.
const _knownCrossFeatureExceptions = <String>{};

/// features/ importing app/ (route constants used for navigation)
const _knownFeatureAppExceptions = {
  'app/router/app_routes_constants', // all features may import this for now
};

void main() {
  group('studioPlatformViolations', () {
    const studioImport = 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
    const platformImport = 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';

    for (final (path, imports) in <(String, List<String>)>[
      ('lib/infrastructure/platform/platform_api_client.dart', [studioImport]),
      ('lib/infrastructure/studio/statement_repository.dart', [platformImport]),
      ('lib/features/auth/data/repositories/mixed_repository.dart', [studioImport, platformImport]),
      ('lib/features/platform_grants/data/grant_repository.dart', [studioImport]),
      ('lib/features/access_requests/data/repositories/access_request_repository.dart', [studioImport]),
    ]) {
      test('fails $path importing ${imports.length == 2 ? 'both' : imports.single.split('/')[2]}', () {
        expect(studioPlatformViolations([(path, imports)]), hasLength(1));
      });
    }

    for (final (path, imports) in <(String, List<String>)>[
      ('lib/infrastructure/platform/platform_api_client.dart', [platformImport]),
      ('lib/infrastructure/studio/statement_repository.dart', [studioImport]),
      ('lib/features/auth/data/repositories/studio_identity_repository.dart', [studioImport]),
      ('lib/features/auth/data/repositories/platform_identity_repository.dart', [platformImport]),
      ('lib/features/platform_grants/data/grant_repository.dart', [platformImport]),
      ('lib/features/access_requests/data/repositories/access_request_repository.dart', [platformImport]),
      ('lib/app/di/app_dependencies.dart', [studioImport, platformImport]),
    ]) {
      test('passes $path', () {
        expect(studioPlatformViolations([(path, imports)]), isEmpty);
      });
    }
  });

  group('Architecture Guard Tests', () {
    late List<File> dartFiles;

    setUpAll(() {
      final libDir = Directory('lib');
      dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('/generated/'))
          .toList();
    });

    test('core/ must not import from shared/, features/, infrastructure/, or app/', () {
      final violations = <String>[];
      final coreFiles = dartFiles.where((f) => f.path.contains('/core/'));

      for (final file in coreFiles) {
        final imports = _getImports(file);
        for (final import in imports) {
          if (import.contains('/shared/') ||
              import.contains('/features/') ||
              import.contains('/infrastructure/') ||
              import.contains('/app/')) {
            final key = '${_relative(file.path)} → ${_importFragment(import)}';
            if (!_isKnownException(key, _knownCoreExceptions)) {
              violations.add('${_relative(file.path)}: imports $import');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'core/ must have zero dependencies on other layers:\n${violations.join('\n')}',
      );
    });

    // infrastructure/ is checked here as well as features/ and app/, because the doc comment above has said
    // "core only" since this file was written and only the other two were ever tested. Nothing under lib/shared/
    // imports infrastructure/ today, so the rule has held on discipline — which is not a guard.
    test('shared/ must not import from features/, app/ or infrastructure/', () {
      final violations = <String>[];
      final sharedFiles = dartFiles.where((f) => f.path.contains('/shared/'));

      for (final file in sharedFiles) {
        final imports = _getImports(file);
        for (final import in imports) {
          if (import.contains('/features/') || import.contains('/app/') || import.contains('/infrastructure/')) {
            final key = '${_relative(file.path)} → ${_importFragment(import)}';
            if (!_isKnownException(key, _knownSharedExceptions)) {
              violations.add('${_relative(file.path)}: imports $import');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'shared/ must not import from features/, app/ or infrastructure/:\n${violations.join('\n')}',
      );
    });

    test('features/ must not import from other features/ internals', () {
      final violations = <String>[];
      final featureFiles = dartFiles.where((f) => f.path.contains('/features/'));

      for (final file in featureFiles) {
        final featureName = _extractFeatureName(file.path);
        if (featureName == null) continue;

        final imports = _getImports(file);
        for (final import in imports) {
          if (!import.contains('/features/')) continue;

          final importedFeature = _extractFeatureNameFromImport(import);
          if (importedFeature != null && importedFeature != featureName) {
            if (!import.contains('/shared/')) {
              final key = '${_relative(file.path)} → ${_importFragment(import)}';
              if (!_isKnownException(key, _knownCrossFeatureExceptions)) {
                violations.add('${_relative(file.path)} ($featureName) imports from $importedFeature: $import');
              }
            }
          }
        }
      }

      expect(violations, isEmpty, reason: 'features must not import from other features:\n${violations.join('\n')}');
    });

    test('features/ must not import from app/', () {
      final violations = <String>[];
      final featureFiles = dartFiles.where((f) => f.path.contains('/features/'));

      for (final file in featureFiles) {
        final imports = _getImports(file);
        for (final import in imports) {
          if (import.contains('/app/')) {
            final fragment = _importFragment(import);
            if (!_knownFeatureAppExceptions.any((e) => fragment.contains(e))) {
              violations.add('${_relative(file.path)}: imports $import');
            }
          }
        }
      }

      expect(violations, isEmpty, reason: 'features/ must not import from app/:\n${violations.join('\n')}');
    });

    test('infrastructure/ must not import from features/ or app/', () {
      final violations = <String>[];
      final infraFiles = dartFiles.where((f) => f.path.contains('/infrastructure/'));

      for (final file in infraFiles) {
        final imports = _getImports(file);
        for (final import in imports) {
          if (import.contains('/features/') || import.contains('/app/')) {
            violations.add('${_relative(file.path)}: imports $import');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'infrastructure/ must not import from features/ or app/:\n${violations.join('\n')}',
      );
    });

    test('Studio and Platform code stay apart', () {
      final files = [for (final file in dartFiles) (_relative(file.path), _getImports(file))];

      final violations = studioPlatformViolations(files);

      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('only shared/utils/external_link.dart imports url_launcher', () {
      final urlLauncherImport = RegExp(r'''^import\s+['"]package:url_launcher/''');
      final violations = dartFiles
          .where((f) => _relative(f.path) != 'lib/shared/utils/external_link.dart')
          .where((f) => f.readAsLinesSync().any(urlLauncherImport.hasMatch))
          .map((f) => _relative(f.path))
          .toList();

      expect(
        violations,
        isEmpty,
        reason:
            'Open links with openExternalLink, which tells the user when a link does not open. A direct url_launcher '
            'call can fail without a word, and canLaunchUrl answers false for https links on Android 11 and higher, '
            'because the manifest declares no <queries> intent for them:\n${violations.join('\n')}',
      );
    });
  });
}

/// The violations of the rules that keep LibreDB Studio and LibreDB Platform code apart, over (file path, imports)
/// pairs with paths relative to the repository and imports in `package:libredb_mobile/...` form:
///
/// - no file under `lib/infrastructure/platform/` imports `infrastructure/studio/`, and the reverse;
/// - no file under `lib/features/` imports both `infrastructure/studio/` and `infrastructure/platform/`;
/// - no file under `lib/features/platform_*/` imports `infrastructure/studio/`;
/// - no file under `lib/features/access_requests/` imports `infrastructure/studio/`, although it serves a Studio
///   session: it asks LibreDB Platform for access, so Platform is the only server it talks to.
///
/// `lib/app/` is exempt: it is the composition root that wires both clients.
List<String> studioPlatformViolations(Iterable<(String, List<String>)> files) {
  const studio = 'libredb_mobile/infrastructure/studio/';
  const platform = 'libredb_mobile/infrastructure/platform/';
  final violations = <String>[];
  for (final (path, imports) in files) {
    final importsStudio = imports.any((i) => i.contains(studio));
    final importsPlatform = imports.any((i) => i.contains(platform));
    if (path.startsWith('lib/infrastructure/platform/') && importsStudio) {
      violations.add('$path: Platform infrastructure imports infrastructure/studio/');
    }
    if (path.startsWith('lib/infrastructure/studio/') && importsPlatform) {
      violations.add('$path: Studio infrastructure imports infrastructure/platform/');
    }
    if (path.startsWith('lib/features/') && importsStudio && importsPlatform) {
      violations.add('$path: a feature file imports both infrastructure/studio/ and infrastructure/platform/');
    }
    if (RegExp(r'^lib/features/platform_[^/]*/').hasMatch(path) && importsStudio) {
      violations.add('$path: a Platform feature imports infrastructure/studio/');
    }
    // access_requests serves a Studio session, so it is named outside platform_*, but it talks to Platform only.
    if (path.startsWith('lib/features/access_requests/') && importsStudio) {
      violations.add('$path: the access requests feature imports infrastructure/studio/');
    }
  }
  return violations;
}

/// Extract package and relative imports from a Dart file (ignore dart: and external packages).
List<String> _getImports(File file) {
  final lines = file.readAsLinesSync();
  final result = <String>[];

  for (final line in lines) {
    if (!line.startsWith('import ')) continue;
    final match = RegExp(r"import '([^']+)'").firstMatch(line);
    if (match == null) continue;
    final importPath = match.group(1)!;

    if (importPath.contains('libredb_mobile')) {
      result.add(importPath);
    } else if (importPath.startsWith('.')) {
      // Resolve relative import to package-style path for consistent checking
      final filePath = file.path.replaceAll('\\', '/');
      final lastSlash = filePath.lastIndexOf('/');
      final fileDir = lastSlash != -1 ? filePath.substring(0, lastSlash) : '.';
      final resolved = _resolveRelativePath(fileDir, importPath);
      // Convert to package:libredb_mobile/... style
      final libIndex = resolved.indexOf('/lib/');
      if (libIndex != -1) {
        final packagePath = 'package:libredb_mobile/${resolved.substring(libIndex + 5)}';
        result.add(packagePath);
      }
    }
  }

  return result;
}

/// Resolve a relative path against a directory, normalizing '..' segments.
String _resolveRelativePath(String dir, String relativePath) {
  final segments = '$dir/$relativePath'.replaceAll('\\', '/').split('/');
  final resolved = <String>[];
  for (final segment in segments) {
    if (segment == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else if (segment != '.' && segment.isNotEmpty) {
      resolved.add(segment);
    }
  }
  return '/${resolved.join('/')}';
}

/// Extract feature name from a file path (e.g., lib/features/users/... → 'users').
String? _extractFeatureName(String path) {
  final match = RegExp(r'/features/([^/]+)/').firstMatch(path);
  return match?.group(1);
}

/// Extract feature name from an import path.
String? _extractFeatureNameFromImport(String import) {
  final match = RegExp(r'/features/([^/]+)/').firstMatch(import);
  return match?.group(1);
}

/// Make path relative for readable output.
String _relative(String path) => path.replaceAll(RegExp(r'^.*/lib/'), 'lib/');

/// Extract a short fragment from the import path (after package:libredb_mobile/).
String _importFragment(String import) {
  return import.replaceAll('package:libredb_mobile/', '').replaceAll('.dart', '');
}

/// Check if a violation key matches any known exception (substring match).
bool _isKnownException(String key, Set<String> knownExceptions) {
  return knownExceptions.any(
    (exception) => key.contains(exception.split(' → ').first) && key.contains(exception.split(' → ').last),
  );
}
