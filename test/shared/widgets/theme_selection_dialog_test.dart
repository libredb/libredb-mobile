@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/widgets/theme_selection_dialog.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ThemeBloc(),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => ThemeSelectionDialog.show(context), child: const Text('Open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  /// The palette the app is actually wearing, read from the bloc the dialog writes to.
  AppThemePalette paletteNow(WidgetTester tester) =>
      BlocProvider.of<ThemeBloc>(tester.element(find.byType(Scaffold).first), listen: false).state.palette;

  group('choosing a palette', () {
    // Tapping a card applies it at once (`theme_selection_dialog.dart:274`), which is what makes the dialog a preview.
    // Both buttons then did the same thing — pop — so a user who tried a palette, disliked it and pressed Cancel kept
    // the one they had just rejected, with no way back to theirs except remembering which it was (#371).
    testWidgets('Cancel puts back the palette the dialog opened on', (tester) async {
      await openDialog(tester, const Size(412, 915));
      final opened = paletteNow(tester);
      final other = AppThemePalette.values.firstWhere((palette) => palette != opened);

      await tester.tap(find.text(other.name[0].toUpperCase() + other.name.substring(1)));
      await tester.pumpAndSettle();
      expect(paletteNow(tester), other, reason: 'the card has to apply at once, or there is nothing to cancel');

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(paletteNow(tester), opened);
    });

    testWidgets('Apply keeps the palette the user chose', (tester) async {
      await openDialog(tester, const Size(412, 915));
      final opened = paletteNow(tester);
      final other = AppThemePalette.values.firstWhere((palette) => palette != opened);

      await tester.tap(find.text(other.name[0].toUpperCase() + other.name.substring(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(paletteNow(tester), other);
    });

    // Cancel was taught to put back what the dialog opened on (#371); the X, the barrier and the back gesture were
    // not, so the same "nothing committed" gesture committed or did not depending on which one the user reached for
    // (#412). Apply is the only action that keeps a palette.
    Future<void> previewAnother(WidgetTester tester, AppThemePalette opened) async {
      final other = AppThemePalette.values.firstWhere((palette) => palette != opened);
      await tester.tap(find.text(other.name[0].toUpperCase() + other.name.substring(1)));
      await tester.pumpAndSettle();
      expect(paletteNow(tester), other, reason: 'the card has to apply at once, or there is nothing to put back');
    }

    testWidgets('closing with the X puts back the palette the dialog opened on', (tester) async {
      await openDialog(tester, const Size(412, 915));
      final opened = paletteNow(tester);
      await previewAnother(tester, opened);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(paletteNow(tester), opened);
      expect(find.byType(ThemeSelectionDialog), findsNothing, reason: 'the X closes the dialog');
    });

    testWidgets('tapping outside the dialog puts back the palette the dialog opened on', (tester) async {
      await openDialog(tester, const Size(412, 915));
      final opened = paletteNow(tester);
      await previewAnother(tester, opened);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(paletteNow(tester), opened);
      expect(find.byType(ThemeSelectionDialog), findsNothing, reason: 'the barrier closes the dialog');
    });

    testWidgets('the back gesture puts back the palette the dialog opened on', (tester) async {
      await openDialog(tester, const Size(412, 915));
      final opened = paletteNow(tester);
      await previewAnother(tester, opened);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(paletteNow(tester), opened);
      expect(find.byType(ThemeSelectionDialog), findsNothing, reason: 'the back gesture closes the dialog');
    });
  });

  // A palette card applies at once and the dialog stays open, so nothing on screen moves enough for a screen reader
  // to notice. Without an announcement a blind user taps a card and hears nothing at all (#375).
  group('a screen reader', () {
    testWidgets('hears that the palette changed', (tester) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
        message,
      ) async {
        final data = (message as Map<Object?, Object?>)['data'] as Map<Object?, Object?>?;
        final text = data?['message'] as String?;
        if (text != null) announcements.add(text);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
      );

      await openDialog(tester, const Size(412, 915));
      final opened = paletteNow(tester);
      final other = AppThemePalette.values.firstWhere((palette) => palette != opened);

      await tester.tap(find.text(other.name[0].toUpperCase() + other.name.substring(1)));
      await tester.pumpAndSettle();

      expect(announcements, isNotEmpty, reason: 'tapping a palette card says nothing to a screen reader');
    });
  });

  group('ThemeSelectionDialog', () {
    testWidgets('names the close button for screen readers in the app language', (tester) async {
      final semantics = tester.ensureSemantics();
      await openDialog(tester, const Size(412, 915), locale: const Locale('tr'));

      expect(
        tester.getSemantics(find.widgetWithIcon(IconButton, Icons.close)),
        isSemantics(tooltip: 'Kapat', isButton: true),
      );
      semantics.dispose();
    });

    testWidgets('puts Cancel and Apply at the end of the dialog when they fit on one line', (tester) async {
      await openDialog(tester, const Size(412, 915));

      final close = tester.getRect(find.widgetWithIcon(IconButton, Icons.close));
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      final apply = tester.getRect(find.widgetWithText(FilledButton, 'Apply'));
      expect(apply.top, cancel.top);
      expect(apply.right, close.right);
    });

    for (final textScale in [1.0, 1.3]) {
      testWidgets('fits a 320 px wide phone at text scale $textScale', (tester) async {
        await openDialog(tester, const Size(320, 568), textScale: textScale);

        expect(tester.takeException(), isNull);
        expect(find.text('Choose Theme'), findsOneWidget);
        expect(find.text('Apply'), findsOneWidget);
      });
    }
  });
  group('ThemeSelectionDialog - language', () {
    testWidgets('shows the palette descriptions without a dash in English', (tester) async {
      await openDialog(tester, const Size(412, 915));

      expect(find.text('Cool neutral, clean and minimal'), findsOneWidget);
    });

    for (final textScale in [1.0, 1.3]) {
      testWidgets('shows its texts in Turkish on a 320 px wide phone at text scale $textScale', (tester) async {
        await openDialog(tester, const Size(320, 568), textScale: textScale, locale: const Locale('tr'));

        expect(tester.takeException(), isNull);
        for (final text in [
          'Tema Seçin',
          'Tercih ettiğiniz tema stilini seçin',
          'Klasik',
          'Soğuk nötr, sade ve minimal',
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(find.widgetWithText(TextButton, 'İptal'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Uygula'), findsOneWidget);
      });
    }
  });
}
