@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/shared/user_data/signed_in_account_scope.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';

const _subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';

/// A store that records each subject it clears, and throws while [failing] is true.
class _FakeStore {
  _FakeStore(this.name);

  final String name;
  bool failing = false;
  final cleared = <String>[];

  /// Completes the clear when given, so a test can hold one in flight.
  Completer<void>? hold;

  UserDataStore get entry => UserDataStore(
    name: name,
    clear: (subject) async {
      cleared.add(subject);
      await hold?.future;
      if (failing) throw StateError('the device refused to remove $name');
    },
  );
}

void main() {
  late _FakeStore drafts;
  late _FakeStore favorites;
  late int signOuts;

  setUp(() {
    drafts = _FakeStore('statement_text');
    favorites = _FakeStore('connection_favorites');
    signOuts = 0;
  });

  Widget buildScreen({String? subject = _subject, Locale locale = const Locale('en')}) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProjectLinks>.value(value: const ProjectLinks()),
        RepositoryProvider<UserDataRegistry>.value(value: UserDataRegistry([drafts.entry, favorites.entry])),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: SignedInAccountScope(
          subject: subject,
          signOut: () async => signOuts++,
          child: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
  }

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(settingsRemoveMyDataKey));
    await tester.tap(find.byKey(settingsRemoveMyDataKey));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Remove my data in a Privacy section while signed in', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Privacy'), findsOneWidget);
    expect(find.descendant(of: find.byKey(settingsRemoveMyDataKey), matching: find.text('Remove my data')), findsOne);
  });

  testWidgets('leaves Remove my data out while Studio has named no account', (tester) async {
    await tester.pumpWidget(buildScreen(subject: null));
    await tester.pumpAndSettle();

    expect(find.byKey(settingsRemoveMyDataKey), findsNothing);
    expect(find.text('Privacy'), findsNothing);
  });

  testWidgets('the confirmation lists what goes and what stays, and Cancel removes nothing', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await openConfirmation(tester);

    for (final text in [
      'Remove my data?',
      'Removed from this phone',
      'SQL editor drafts',
      'Statement history',
      'Starred connections',
      'Recent connections',
      'The last open connection and database',
      'Collapsed sections of the connection list',
      'Kept on this phone',
      'Language, theme and result view',
      'You are signed out once your data is removed.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final confirm = tester.widget<FilledButton>(find.byKey(removeMyDataConfirmKey));
    final context = tester.element(find.byKey(removeMyDataConfirmKey));
    expect(
      confirm.style?.backgroundColor?.resolve({}),
      Theme.of(context).colorScheme.error,
      reason: 'the confirm button is destructive',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Remove my data?'), findsNothing);
    expect(drafts.cleared, isEmpty);
    expect(favorites.cleared, isEmpty);
    expect(signOuts, 0);
  });

  testWidgets('confirming clears every store for the account, then signs out', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await openConfirmation(tester);
    await tester.tap(find.byKey(removeMyDataConfirmKey));
    await tester.pumpAndSettle();

    expect(drafts.cleared, [_subject]);
    expect(favorites.cleared, [_subject]);
    expect(signOuts, 1);
  });

  testWidgets('shows the progress and takes no second tap while the stores clear', (tester) async {
    drafts.hold = Completer<void>();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await openConfirmation(tester);
    await tester.tap(find.byKey(removeMyDataConfirmKey));
    // The progress turns until the stores are cleared, so the dialog's exit is pumped by time.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Remove my data?'), findsNothing);
    expect(find.byKey(removeMyDataProgressKey), findsOneWidget);
    await tester.tap(find.byKey(settingsRemoveMyDataKey), warnIfMissed: false);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Remove my data?'), findsNothing, reason: 'the tile is disabled while the stores clear');

    drafts.hold!.complete();
    await tester.pumpAndSettle();
    expect(drafts.cleared, [_subject]);
    expect(signOuts, 1);
  });

  testWidgets('a store that fails keeps the user signed in with the failure and Retry, which completes', (
    tester,
  ) async {
    favorites.failing = true;
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await openConfirmation(tester);
    await tester.tap(find.byKey(removeMyDataConfirmKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Some of your data could not be removed from this phone, so you are still signed in.'),
      findsOneWidget,
    );
    expect(find.textContaining('refused'), findsNothing, reason: 'the failure names no store or stored value');
    expect(find.byKey(removeMyDataRetryKey), findsOneWidget);
    expect(signOuts, 0);

    favorites.failing = false;
    await tester.ensureVisible(find.byKey(removeMyDataRetryKey));
    await tester.tap(find.byKey(removeMyDataRetryKey));
    await tester.pumpAndSettle();

    expect(drafts.cleared, [_subject, _subject]);
    expect(favorites.cleared, [_subject, _subject]);
    expect(signOuts, 1);
    expect(find.byKey(removeMyDataRetryKey), findsNothing);
  });

  testWidgets('shows the Privacy section and the confirmation in Turkish', (tester) async {
    await tester.pumpWidget(buildScreen(locale: const Locale('tr')));
    await tester.pumpAndSettle();

    expect(find.text('Gizlilik'), findsOneWidget);
    expect(find.text('Verilerimi sil'), findsOneWidget);
    await openConfirmation(tester);

    expect(find.text('Verileriniz silinsin mi?'), findsOneWidget);
    expect(find.text('Dil, tema ve sonuç görünümü'), findsOneWidget);
    expect(find.text('Sil ve oturumu kapat'), findsOneWidget);
  });
}
