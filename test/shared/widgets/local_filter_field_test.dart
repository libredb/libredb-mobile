@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/local_filter_field.dart';

void main() {
  Future<List<String>> pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(body: LocalFilterField(onChanged: changes.add)),
      ),
    );
    return changes;
  }

  testWidgets('reports each change of the text as typed, unfolded', (tester) async {
    final changes = await pump(tester);

    await tester.enterText(find.byType(TextField), 'İstan');

    expect(changes, ['İstan']);
  });

  testWidgets('offers a clear button only while it holds text, which empties it and reports the empty text', (
    tester,
  ) async {
    final changes = await pump(tester);
    expect(find.byTooltip('Clear filter'), findsNothing);

    await tester.enterText(find.byType(TextField), 'orders');
    await tester.pump();
    await tester.tap(find.byTooltip('Clear filter'));
    await tester.pump();

    expect(changes, ['orders', '']);
    expect(find.text('orders'), findsNothing);
    expect(find.byTooltip('Clear filter'), findsNothing);
  });

  testWidgets('says what it does in the user\'s language', (tester) async {
    await pump(tester, locale: const Locale('tr'));
    expect(find.text('Filtrele'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(find.byTooltip('Filtreyi temizle'), findsOneWidget);
  });
}
