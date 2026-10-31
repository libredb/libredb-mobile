@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_list_view.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

void main() {
  Future<void> pumpHeader(WidgetTester tester, {required int count, required Locale locale}) async {
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
          body: ConnectionSectionHeader(title: 'Finance', count: count, collapsed: false, onTap: () {}),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('groups the count the Turkish way', (tester) async {
    await pumpHeader(tester, count: 1234, locale: const Locale('tr'));

    expect(find.text('1.234'), findsOneWidget);
    expect(find.text('1234'), findsNothing);
  });

  testWidgets('groups the count the English way', (tester) async {
    await pumpHeader(tester, count: 1234, locale: const Locale('en'));

    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('1234'), findsNothing);
  });

  testWidgets('a count below a thousand is not grouped', (tester) async {
    await pumpHeader(tester, count: 12, locale: const Locale('tr'));

    expect(find.text('12'), findsOneWidget);
  });
}
