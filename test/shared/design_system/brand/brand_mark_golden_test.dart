import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/brand/brand_mark.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

import '../../../support/test_env.dart';

/// What the mark actually draws.
///
/// Every other test of it measures geometry — that the paths parse, that the rows are where the design system puts
/// them, that nothing is empty. None of those can tell a correct hexagon from one assembled wrong, and this is the
/// one shape in the app where "approximately right" is not right at all: it is the product's mark (#390).
void main() {
  setUpAll(() => TestEnv.autoReset = false);

  Widget marks({required bool dark}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const BrandMark(size: 24),
              const BrandMark(size: 48),
              const BrandMark(size: 96),
              // The single-ink form, on the ground it exists for.
              BrandMark(size: 48, color: Theme.of(context).colorScheme.onSurface),
            ],
          ),
        ),
      ),
    ),
  );

  for (final (name, dark) in [('light', false), ('dark', true)]) {
    goldenTest(
      'BrandMark — $name',
      fileName: 'brand_mark_$name',
      pumpBeforeTest: pumpOnce,
      builder: () => GoldenTestGroup(
        columns: 1,
        children: [
          GoldenTestScenario(
            name: 'three sizes in the two gradients, and one in a single ink',
            child: SizedBox(width: 400, height: 220, child: marks(dark: dark)),
          ),
        ],
      ),
    );
  }
}
