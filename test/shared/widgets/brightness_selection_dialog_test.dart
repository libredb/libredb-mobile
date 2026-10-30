@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/brightness_selection_dialog.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The dialog over a page, with the bloc already on [seed] so the dialog opens on that mode.
  Future<void> openDialog(WidgetTester tester, {ThemeMode seed = ThemeMode.system}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ThemeBloc()..add(SelectBrightness(themeMode: seed)),
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => BrightnessSelectionDialog.show(context), child: const Text('Open')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  /// The mode the app is actually on, read from the bloc the dialog writes to.
  ThemeMode modeNow(WidgetTester tester) =>
      BlocProvider.of<ThemeBloc>(tester.element(find.byType(Scaffold).first), listen: false).state.themeMode;

  /// The card of the mode titled [title] carries the check mark only while that mode is the one in force.
  Finder checkOn(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
    matching: find.byIcon(Icons.check_circle),
  );

  const titles = {ThemeMode.system: 'Follow the phone', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'};

  group('BrightnessSelectionDialog', () {
    testWidgets('offers all three modes, the phone among them', (tester) async {
      await openDialog(tester);

      expect(find.text('Day and night'), findsOneWidget);
      for (final title in titles.values) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    for (final mode in ThemeMode.values) {
      testWidgets('shows ${titles[mode]} as the one in force when the app is on $mode', (tester) async {
        await openDialog(tester, seed: mode);

        expect(checkOn(titles[mode]!), findsOneWidget);
        for (final other in ThemeMode.values.where((value) => value != mode)) {
          expect(checkOn(titles[other]!), findsNothing, reason: titles[other]);
        }
      });
    }

    testWidgets('picking a mode applies it at once', (tester) async {
      await openDialog(tester, seed: ThemeMode.light);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(modeNow(tester), ThemeMode.dark);
    });

    // The rule #371 made real for the palette dialog: a card applies at once, so Cancel has to put back what the
    // dialog opened on — a user who tries dark, dislikes it and cancels must not be left in dark.
    testWidgets('Cancel puts back the mode the dialog opened on', (tester) async {
      await openDialog(tester, seed: ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(modeNow(tester), ThemeMode.dark, reason: 'the card has to apply at once, or there is nothing to cancel');

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(modeNow(tester), ThemeMode.system);
      expect(find.text('Day and night'), findsNothing, reason: 'Cancel closes the dialog');
    });

    testWidgets('Cancel puts back the phone even after two tries', (tester) async {
      await openDialog(tester, seed: ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(modeNow(tester), ThemeMode.system);
    });

    testWidgets('Apply keeps the mode the user chose', (tester) async {
      await openDialog(tester, seed: ThemeMode.dark);

      await tester.tap(find.text('Follow the phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(modeNow(tester), ThemeMode.system);
      expect(find.text('Day and night'), findsNothing, reason: 'Apply closes the dialog');
    });

    // The X sits one tap from Cancel and reads as the same gesture — "I am done here, nothing committed". Leaving the
    // previewed mode in force, and in storage across restarts, made one of the two commit and the other not (#412).
    testWidgets('closing with the X puts back the mode the dialog opened on', (tester) async {
      await openDialog(tester, seed: ThemeMode.system);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(
        modeNow(tester),
        ThemeMode.light,
        reason: 'the card has to apply at once, or there is nothing to put back',
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(modeNow(tester), ThemeMode.system);
      expect(find.text('Day and night'), findsNothing, reason: 'the X closes the dialog');
    });

    testWidgets('tapping outside the dialog puts back the mode the dialog opened on', (tester) async {
      await openDialog(tester, seed: ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(modeNow(tester), ThemeMode.system);
      expect(find.text('Day and night'), findsNothing, reason: 'the barrier closes the dialog');
    });

    testWidgets('the back gesture puts back the mode the dialog opened on', (tester) async {
      await openDialog(tester, seed: ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(modeNow(tester), ThemeMode.system);
      expect(find.text('Day and night'), findsNothing, reason: 'the back gesture closes the dialog');
    });

    testWidgets('names the modes in Turkish', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => ThemeBloc(),
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(onPressed: () => BrightnessSelectionDialog.show(context), child: const Text('Aç')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      for (final text in ['Gece ve gündüz', 'Telefonun ayarına uy', 'Açık', 'Koyu']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });
  });
}
