@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/data/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/features/connections/data/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/infrastructure/storage/active_catalog_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/active_connection_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/result_view_mode_preferences.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/features/settings/presentation/pages/settings_screen.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/shared/user_data/signed_in_account_scope.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/shell/top_bar/top_bar_widget.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/test_env.dart';
import '../../../../support/url_launcher_stub.dart';
import '../../../../mocks/mock_classes.dart';
import '../../../../support/user_menu.dart';

const _docs = 'https://docs.acme.example';

/// Device preferences that refuse to store a language, like a device that is out of space.
class _LanguageRefusingStorage implements AppLocalStorage {
  const _LanguageRefusingStorage();

  @override
  Future<bool> save(String key, dynamic value) async =>
      key == StorageKeys.language.key ? false : AppLocalStorage().save(key, value);
  @override
  Future<dynamic> read(String key) => AppLocalStorage().read(key);
  @override
  Future<bool> remove(String key) => AppLocalStorage().remove(key);
  @override
  Future<void> clear() => AppLocalStorage().clear();
  @override
  void setPreferencesInstance(SharedPreferences prefs) => AppLocalStorage().setPreferencesInstance(prefs);
}

/// The mock app with [statementText] as its statement text store, which in a widget test cannot reach the files.
class _StatementTextDependencies extends MockSignInDependencies {
  _StatementTextDependencies(this.statementText);

  final IStatementTextStore statementText;

  @override
  IStatementTextStore createStatementTextStore(ISecureStorage secureStorage) => statementText;
}

class _LocalStorageDependencies extends MockSignInDependencies {
  _LocalStorageDependencies(this.localStorage, {super.projectLinks});

  final AppLocalStorage localStorage;

  @override
  AppLocalStorage createLocalStorage() => localStorage;
}

void main() {
  // The app links to the documentation [docs].
  Widget buildTestableWidget({String docs = _docs, Locale locale = const Locale('en')}) {
    final router = GoRouter(
      initialLocation: ApplicationRoutesConstants.settings,
      routes: [
        GoRoute(
          path: ApplicationRoutesConstants.settings,
          // Studio has named no account, so the Privacy section is left out.
          builder: (context, state) => SignedInAccountScope(
            subject: null,
            signOut: () async {},
            reloadStoredData: () {},
            child: const Scaffold(body: SettingsScreen()),
          ),
        ),
      ],
    );

    return MultiRepositoryProvider(
      providers: [RepositoryProvider<ProjectLinks>.value(value: ProjectLinks(docs: docs))],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
      ),
    );
  }

  // The real app, signed in, on settings. The shell shows the account name in the top bar once the mock API answers
  // after its 500 ms delay, so let that land before the screen is compared. The app links to the documentation [docs]
  // and, when given, the device preferences [localStorage].
  Future<void> pumpAppOnSettings(
    WidgetTester tester, {
    String docs = _docs,
    AppLocalStorage? localStorage,
    AppDependencies? dependencies,
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    TestEnv.authenticate();

    final projectLinks = ProjectLinks(docs: docs);
    await tester.pumpWidget(
      App(
        language: 'en',
        dependencies:
            dependencies ??
            (localStorage == null
                ? MockSignInDependencies(projectLinks: projectLinks)
                : _LocalStorageDependencies(localStorage, projectLinks: projectLinks)),
      ),
    );
    await tester.pump();
    (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).go(
      ApplicationRoutesConstants.settings,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  group('SettingsScreen Tests', () {
    testWidgets('renders all settings tiles', (WidgetTester tester) async {
      TestEnv.authenticate();
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Assert via Keys only — text-based asserts would couple the
      // test to the active locale (every title comes from S.of(context)).
      // Key presence is enough to guard the screen layout against
      // accidental tile removal.
      expect(find.byKey(settingsChangeLanguageButtonKey), findsOneWidget);
      expect(find.byKey(settingsWebsiteButtonKey), findsOneWidget);
      expect(find.byKey(settingsLicensesButtonKey), findsOneWidget);
      // Logout intentionally lives only in the profile sheet of the shell:
      // settings does not own auth-session lifecycle (cross-feature).
    });

    testWidgets('names the Help & Resources link Documentation', (WidgetTester tester) async {
      TestEnv.authenticate();
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Help & Resources'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(settingsWebsiteButtonKey), matching: find.text('Documentation')),
        findsOneWidget,
      );
      expect(find.text('Read the documentation and guides on GitHub'), findsOneWidget);
    });

    // The licences page shows the NOTICE that carries the MIT notice of the template the app grew from.
    testWidgets('opens the licences page from Help & Resources', (WidgetTester tester) async {
      TestEnv.authenticate();
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byKey(settingsLicensesButtonKey), matching: find.text('Licenses')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(settingsLicensesButtonKey));
      await tester.tap(find.byKey(settingsLicensesButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  group('SettingsScreen - Turkish', () {
    testWidgets('shows the subtitles and the appearance section in Turkish', (tester) async {
      await tester.pumpWidget(buildTestableWidget(locale: const Locale('tr')));
      await tester.pumpAndSettle();

      for (final text in [
        'Hesap tercihlerinizi yönetin',
        'Görünüm',
        'Tema',
        'Tercih ettiğiniz tema stilini seçin',
        'Lisanslar',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });
  });

  group('SettingsScreen - documentation link that does not open', () {
    for (final failure in UrlLauncherFailure.values) {
      testWidgets('tapping Documentation shows a message when ${failure.description}', (WidgetTester tester) async {
        final calls = stubFailingUrlLauncher(failure);
        await pumpAppOnSettings(tester);

        await expectTapShowsMessage(tester, find.byKey(settingsWebsiteButtonKey));
        expect(calls.requestedUrls, contains(_docs));
      });
    }
  });

  group('SettingsScreen - language', () {
    testWidgets('choosing Turkish shows the app in Turkish at once and again at the next start', (tester) async {
      await pumpAppOnSettings(tester);
      expect(find.text('Help & Resources'), findsOneWidget);

      await tester.tap(find.byKey(settingsChangeLanguageButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Türkçe'));
      await tester.pumpAndSettle();

      expect(find.text('Yardım ve Kaynaklar'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(TopBarWidget), matching: find.text('Ayarlar')),
        findsOneWidget,
        reason: 'the top bar of the shell switches too',
      );
      expect(find.descendant(of: find.byKey(settingsChangeLanguageButtonKey), matching: find.text('Türkçe')), findsOne);
      expect(find.text('Help & Resources'), findsNothing);

      // The next cold start: a new App, which reads the stored language.
      await tester.pumpWidget(const SizedBox());
      await pumpAppOnSettings(tester);

      expect(find.text('Yardım ve Kaynaklar'), findsOneWidget);
      expect(find.text('Help & Resources'), findsNothing);
    });

    testWidgets('keeps the picked language after a logout and at the next start', (tester) async {
      await pumpAppOnSettings(tester);
      await tester.tap(find.byKey(settingsChangeLanguageButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Türkçe'));
      await tester.pumpAndSettle();

      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.widgetWithText(FilledButton, 'Evet'));
      await tester.pumpAndSettle();
      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.text("Studio'ya giriş yap"), findsOneWidget);

      // The next cold start: a new App, which reads the stored language.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
      expect(find.text("Studio'ya giriş yap"), findsOneWidget);
      expect(find.text('Sign in to Studio'), findsNothing);
    });

    testWidgets('keeps the language and says so when the device cannot store it', (tester) async {
      await pumpAppOnSettings(tester, localStorage: const _LanguageRefusingStorage());

      await tester.tap(find.byKey(settingsChangeLanguageButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Türkçe'));
      await tester.pumpAndSettle();

      expect(find.text('Could not change the language'), findsOneWidget);
      expect(find.text('Select Language'), findsNothing, reason: 'the dialog closes');
      expect(find.text('Help & Resources'), findsOneWidget);
      expect(find.text('Yardım ve Kaynaklar'), findsNothing);
      expect(await AppLocalStorage().read(StorageKeys.language.key), isNull);

      // Let the snack bar time out.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });
  });

  group('SettingsScreen - Remove my data', () {
    // The account the mock GET /api/auth/me names (assets/mock/GET_auth_me.json), and another one on the same phone.
    const subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';
    const other = 'b0d7c4e1-1111-4222-8333-944455556666';
    const favorites = ConnectionFavorites(starred: {'seed:dev-postgres'}, recent: ['seed:dev-postgres']);

    testWidgets('removes what the phone keeps for the account, keeps the device preferences, and signs out', (
      tester,
    ) async {
      final statementText = MockIStatementTextStore();
      when(() => statementText.clearSubject(any())).thenAnswer((_) async => const Success(null));
      await FavoriteConnectionsRepository().write(subject, favorites);
      await FavoriteConnectionsRepository().write(other, favorites);
      await ActiveConnectionPreferences().write(subject, 'seed:dev-postgres-server');
      await ActiveConnectionPreferences().write(other, 'seed:dev-postgres-server');
      await ActiveCatalogPreferences().write(subject, 'seed:dev-postgres-server', 'archive');
      await ActiveCatalogPreferences().write(other, 'seed:dev-postgres-server', 'postgres');
      await CollapsedSectionsRepository().write({'group:Sales'});
      await ResultViewModePreferences().write(ResultViewMode.table);
      await AppLocalStorage().save(StorageKeys.brightness.key, 'dark');

      await pumpAppOnSettings(tester, dependencies: _StatementTextDependencies(statementText));
      await tester.ensureVisible(find.byKey(settingsRemoveMyDataKey));
      await tester.tap(find.byKey(settingsRemoveMyDataKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(removeMyDataConfirmKey));
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsOneWidget, reason: 'the user is signed out');
      verify(() => statementText.clearSubject(subjectHash(subject))).called(1);
      verifyNever(() => statementText.clearSubject(subjectHash(other)));
      expect(await FavoriteConnectionsRepository().read(subject), ConnectionFavorites.empty);
      expect(await FavoriteConnectionsRepository().read(other), favorites);
      expect(await ActiveConnectionPreferences().read(subject), isNull);
      expect(await ActiveConnectionPreferences().read(other), 'seed:dev-postgres-server');
      expect(await ActiveCatalogPreferences().read(subject, 'seed:dev-postgres-server'), isNull);
      expect(await ActiveCatalogPreferences().read(other, 'seed:dev-postgres-server'), 'postgres');
      expect(await CollapsedSectionsRepository().read(), isEmpty);
      expect(await ResultViewModePreferences().read(), ResultViewMode.table);
      expect(await AppLocalStorage().read(StorageKeys.brightness.key), 'dark');
    });

    testWidgets('a store that fails keeps the user signed in on settings with Retry', (tester) async {
      final statementText = MockIStatementTextStore();
      when(() => statementText.clearSubject(any()))
          .thenAnswer((_) async => const Failure(UnknownError('Could not clear an account: refused')));
      await FavoriteConnectionsRepository().write(subject, favorites);
      await ActiveConnectionPreferences().write(subject, 'seed:sales-postgres');

      await pumpAppOnSettings(tester, dependencies: _StatementTextDependencies(statementText));
      final settings = tester.element(find.byType(SettingsScreen));
      expect(settings.read<FavoriteConnectionsBloc>().state, const FavoriteConnectionsReady(favorites));
      expect(settings.read<ActiveConnectionCubit>().state.connection?.id, 'seed:sales-postgres');
      await tester.ensureVisible(find.byKey(settingsRemoveMyDataKey));
      await tester.tap(find.byKey(settingsRemoveMyDataKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(removeMyDataConfirmKey));
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsNothing);
      // The app reads again what is left, so a later star or open never writes the removed favorites back.
      expect(settings.read<FavoriteConnectionsBloc>().state, const FavoriteConnectionsReady(ConnectionFavorites.empty));
      expect(settings.read<ActiveConnectionCubit>().state.connection, isNull);
      expect(find.byKey(removeMyDataRetryKey), findsOneWidget);
      expect(
        await FavoriteConnectionsRepository().read(subject),
        ConnectionFavorites.empty,
        reason: 'every store is tried',
      );

      when(() => statementText.clearSubject(any())).thenAnswer((_) async => const Success(null));
      await tester.ensureVisible(find.byKey(removeMyDataRetryKey));
      await tester.tap(find.byKey(removeMyDataRetryKey));
      await tester.pumpAndSettle();

      expect(find.byKey(loginButtonSsoKey), findsOneWidget);
    });
  });

  group('SettingsScreen - documentation link that opens', () {
    for (final canLaunch in [true, false]) {
      testWidgets('tapping Documentation opens it and shows no message when canLaunchUrl answers $canLaunch', (
        WidgetTester tester,
      ) async {
        final calls = stubOpeningUrlLauncher(canLaunch: canLaunch);
        await pumpAppOnSettings(tester);

        await expectTapShowsNoMessage(tester, find.byKey(settingsWebsiteButtonKey));
        expect(calls.launchedUrls, [_docs]);
      });
    }
  });
}
