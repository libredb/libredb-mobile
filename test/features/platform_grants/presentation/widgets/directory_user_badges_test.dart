@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/widgets/directory_user_badges.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

void main() {
  Future<void> pumpNarrow(WidgetTester tester, Widget child, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 240, child: Wrap(children: [child])),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final locale in const [Locale('en'), Locale('tr')]) {
    testWidgets('the long seat and role notes wrap in a narrow row instead of overflowing ($locale)', (tester) async {
      await pumpNarrow(tester, const SeatNote(active: false), locale: locale);
      expect(tester.takeException(), isNull);

      await pumpNarrow(tester, const StudioRoleBadge(role: null), locale: locale);
      expect(tester.takeException(), isNull);
    });
  }
}
