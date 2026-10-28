@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/design_system/theme/semantic_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The twelve values of each scope are not restated here. They come from `tool/design-system/tokens/theme.css`
  // and `test/architecture/design_system_import_test.dart` reads that file and holds them to it; a second copy
  // of the same table in this file would drift from the first, and a drifted copy is worse than no copy (#283).
  //
  // What this file owns is the *rule* the twelve follow, which the CSS cannot state: one ink per scope, and a
  // container whose label is its own colour. Both would catch the shape of the mistake that used to ship here —
  // `onWarning` was black while the other two were white, and Yellow 500 as text on white was 1.92:1.
  for (final (scope, colors, ink) in [
    ('light', SemanticColors.light, const Color(0xFFFFFFFF)),
    ('dark', SemanticColors.dark, const Color(0xFF0B0D18)),
  ]) {
    group('SemanticColors $scope', () {
      test('every status colour carries the same ink', () {
        expect(
          [colors.onSuccess, colors.onWarning, colors.onInfo],
          everyElement(ink),
          reason: "what sits on a filled status colour is the scope's --text-inverse, the same for all three",
        );
      });

      test("every container's label is its own status colour", () {
        expect(colors.onSuccessContainer, colors.success);
        expect(colors.onWarningContainer, colors.warning);
        expect(
          colors.onInfoContainer,
          colors.info,
          reason: 'the container is --<kind>-bg and its label is --<kind>-text, the same token as the colour',
        );
      });
    });
  }

  group('SemanticColors light and dark differ', () {
    test('success colors differ between light and dark', () {
      expect(SemanticColors.light.success, isNot(equals(SemanticColors.dark.success)));
    });

    test('warning colors differ between light and dark', () {
      expect(SemanticColors.light.warning, isNot(equals(SemanticColors.dark.warning)));
    });

    test('info colors differ between light and dark', () {
      expect(SemanticColors.light.info, isNot(equals(SemanticColors.dark.info)));
    });
  });

  group('SemanticColors copyWith', () {
    test('returns new instance with updated success', () {
      const original = SemanticColors.light;
      final updated = original.copyWith(success: const Color(0xFF000000));
      expect(updated.success, const Color(0xFF000000));
      expect(updated.onSuccess, original.onSuccess);
      expect(updated.warning, original.warning);
      expect(updated.info, original.info);
    });

    test('returns new instance with updated warning', () {
      const original = SemanticColors.light;
      final updated = original.copyWith(warning: const Color(0xFFFF0000));
      expect(updated.warning, const Color(0xFFFF0000));
      expect(updated.success, original.success);
    });

    test('returns new instance with updated info', () {
      const original = SemanticColors.light;
      final updated = original.copyWith(info: const Color(0xFF00FF00));
      expect(updated.info, const Color(0xFF00FF00));
      expect(updated.success, original.success);
    });

    test('preserves all values when no arguments provided', () {
      const original = SemanticColors.light;
      final copy = original.copyWith();
      expect(copy.success, original.success);
      expect(copy.onSuccess, original.onSuccess);
      expect(copy.successContainer, original.successContainer);
      expect(copy.onSuccessContainer, original.onSuccessContainer);
      expect(copy.warning, original.warning);
      expect(copy.onWarning, original.onWarning);
      expect(copy.warningContainer, original.warningContainer);
      expect(copy.onWarningContainer, original.onWarningContainer);
      expect(copy.info, original.info);
      expect(copy.onInfo, original.onInfo);
      expect(copy.infoContainer, original.infoContainer);
      expect(copy.onInfoContainer, original.onInfoContainer);
    });

    test('updates all container colors', () {
      const original = SemanticColors.light;
      final updated = original.copyWith(
        successContainer: const Color(0xFF111111),
        onSuccessContainer: const Color(0xFF222222),
        warningContainer: const Color(0xFF333333),
        onWarningContainer: const Color(0xFF444444),
        infoContainer: const Color(0xFF555555),
        onInfoContainer: const Color(0xFF666666),
      );
      expect(updated.successContainer, const Color(0xFF111111));
      expect(updated.onSuccessContainer, const Color(0xFF222222));
      expect(updated.warningContainer, const Color(0xFF333333));
      expect(updated.onWarningContainer, const Color(0xFF444444));
      expect(updated.infoContainer, const Color(0xFF555555));
      expect(updated.onInfoContainer, const Color(0xFF666666));
    });
  });

  group('SemanticColors lerp', () {
    test('lerp at t=0 returns start colors', () {
      const start = SemanticColors.light;
      const end = SemanticColors.dark;
      final result = start.lerp(end, 0.0);
      expect(result.success, start.success);
      expect(result.warning, start.warning);
      expect(result.info, start.info);
    });

    test('lerp at t=1 returns end colors', () {
      const start = SemanticColors.light;
      const end = SemanticColors.dark;
      final result = start.lerp(end, 1.0);
      expect(result.success, end.success);
      expect(result.warning, end.warning);
      expect(result.info, end.info);
    });

    test('lerp at t=0.5 returns intermediate colors', () {
      const start = SemanticColors.light;
      const end = SemanticColors.dark;
      final result = start.lerp(end, 0.5);
      expect(result.success, Color.lerp(start.success, end.success, 0.5));
      expect(result.warning, Color.lerp(start.warning, end.warning, 0.5));
      expect(result.info, Color.lerp(start.info, end.info, 0.5));
    });

    test('lerp with non-SemanticColors returns this', () {
      const start = SemanticColors.light;
      final result = start.lerp(null, 0.5);
      expect(result.success, start.success);
      expect(result.warning, start.warning);
      expect(result.info, start.info);
    });
  });

  group('SemanticColorsExtension', () {
    testWidgets('provides semantic colors from theme', (tester) async {
      late SemanticColors capturedColors;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [SemanticColors.light]),
          home: Builder(
            builder: (context) {
              capturedColors = context.semanticColors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedColors.success, SemanticColors.light.success);
      expect(capturedColors.warning, SemanticColors.light.warning);
      expect(capturedColors.info, SemanticColors.light.info);
    });

    testWidgets('provides dark semantic colors from dark theme', (tester) async {
      late SemanticColors capturedColors;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [SemanticColors.dark]),
          home: Builder(
            builder: (context) {
              capturedColors = context.semanticColors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedColors.success, SemanticColors.dark.success);
      expect(capturedColors.warning, SemanticColors.dark.warning);
      expect(capturedColors.info, SemanticColors.dark.info);
    });
  });
}
