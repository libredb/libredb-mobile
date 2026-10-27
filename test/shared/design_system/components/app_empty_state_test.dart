@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';

/// The icon on an empty screen.
///
/// It is the largest thing there and was the hardest to see: drawn at `onSurfaceVariant.withAlpha(128)`, half
/// transparent over the surface, which halves a contrast that was already the scheme's muted one (#373).
void main() {
  testWidgets('the icon stands out from the surface it sits on', (tester) async {
    late ColorScheme scheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return const Scaffold(body: AppEmptyState(title: 'Nothing here'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byType(Icon));
    // Flattened against the surface, because a transparent colour is only as visible as what shows through it.
    final shown = Color.alphaBlend(icon.color!, scheme.surface);
    expect(
      contrastRatio(shown, scheme.surface),
      greaterThanOrEqualTo(3.0),
      reason: 'the one thing on an empty screen is the thing hardest to see',
    );
  });
}
