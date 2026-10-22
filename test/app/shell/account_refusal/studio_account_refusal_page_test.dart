@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/account_refusal/studio_account_refusal_page.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';

void main() {
  late int retries;
  late int signOuts;

  setUp(() {
    retries = 0;
    signOuts = 0;
  });

  // The progress of a retry spins for as long as it shows, so the page is pumped once instead of until it settles.
  Future<void> pumpPage(
    WidgetTester tester,
    AppErrorCode errorCode, {
    bool retrying = false,
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: StudioAccountRefusalPage(
          errorCode: errorCode,
          retrying: retrying,
          onRetry: () => retries++,
          onSignOut: () => signOuts++,
        ),
      ),
    );
    await tester.pump();
  }

  for (final (code, message) in [
    (AppErrorCode.studioAccountHasNoRole, 'This account has no role in Studio. Ask an administrator to give it one.'),
    (
      AppErrorCode.studioAccountHasNoIdentity,
      "Studio cannot tell who this account is. Ask an administrator to check the account's email and username.",
    ),
  ]) {
    testWidgets('says why Studio refused the account for ${code.key}, with Retry and Logout', (tester) async {
      await pumpPage(tester, code);

      expect(find.text('Your account has no access to Studio'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.descendant(of: find.byKey(accountRefusalRetryKey), matching: find.text('Retry')), findsOneWidget);
      expect(find.descendant(of: find.byKey(accountRefusalSignOutKey), matching: find.text('Logout')), findsOneWidget);
    });
  }

  testWidgets('Retry asks again and Logout signs out, each only when tapped', (tester) async {
    await pumpPage(tester, AppErrorCode.studioAccountHasNoRole);
    expect((retries, signOuts), (0, 0), reason: 'the page neither retries nor signs out by itself');

    await tester.tap(find.byKey(accountRefusalRetryKey));
    expect((retries, signOuts), (1, 0));

    await tester.tap(find.byKey(accountRefusalSignOutKey));
    expect((retries, signOuts), (1, 1));
  });

  testWidgets('while Studio is asked again, Retry shows progress and takes no second tap', (tester) async {
    await pumpPage(tester, AppErrorCode.studioAccountHasNoRole, retrying: true);

    expect(
      find.descendant(of: find.byKey(accountRefusalRetryKey), matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(accountRefusalRetryKey));
    expect(retries, 0);

    await tester.tap(find.byKey(accountRefusalSignOutKey));
    expect(signOuts, 1, reason: 'the user can still sign out');
  });

  testWidgets('is translated', (tester) async {
    await pumpPage(tester, AppErrorCode.studioAccountHasNoRole, language: 'tr');

    expect(find.text("Hesabınızın Studio'ya erişimi yok"), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(find.text('Çıkış Yap'), findsOneWidget);
  });
}
