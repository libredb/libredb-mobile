@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/features/platform_status/presentation/pages/platform_unreachable_page.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_unreachable_page.dart';
import 'package:libredb_mobile/app/session/platform_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/platform_shell.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

import '../../../../support/test_env.dart';
import '../../../../support/login_harness.dart';

import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/shell/responsive_scaffold.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/community_card_grid.dart';
import 'package:libredb_mobile/shared/widgets/community/community_chip_row.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/utils/app_constants.dart';
import 'package:go_router/go_router.dart';

import '../../../../support/user_menu.dart';

const _discoveryMessage =
    'The identity provider could not be reached. Try again later, or contact your administrator if this continues.';
const _failedMessage = 'Sign-in failed. Please try again.';
const _refusedMessage = 'Studio did not accept this sign-in. Try again, or ask an administrator for access.';
const _noRoleMessage = 'This account has no role in Studio. Ask an administrator to give it one.';
const _insecureConnectionMessage =
    'The connection could not be verified as secure, so it was blocked. Try again later or on another network.';
const _configMessage = 'This build has no sign-in settings. Ask whoever gave you the app for a complete build.';
const _adminRoleRequiredMessage = 'This account is not a Platform admin. Sign in through Studio instead.';
const _platformNotConfiguredMessage =
    'Platform mode is not available in this build of the app. Sign in through Studio.';

/// The subtitle under the heading. The phone and the wide layout say different things: the phone names the product
/// and what it does, because it is a first-time user's whole introduction, while the wide layout's brand panel
/// already carries both, so its form panel says how to sign in instead (`login_page.dart`, `_formHeading`).
const _phoneSubtitle = 'Reach the databases LibreDB Studio grants you, from your phone.';
const _phoneSubtitleTr = "LibreDB Studio'nun size açtığı veritabanlarına telefonunuzdan ulaşın.";
const _wideSubtitle = 'Sign in with your organization account.';
const _wideSubtitleTr = 'Kurumsal hesabınızla giriş yapın.';

const _studioHelper = 'Browse and query the databases Studio grants you.';
const _platformHelper = 'For Platform admins. Your first Platform sign-in takes one admin seat of the license.';
const _withPlatform = PlatformConfigured();

void main() {
  // The real app starts unauthenticated after the global reset, so it lands on /login.
  Future<void> pumpLogin(WidgetTester tester, {String language = 'en'}) async {
    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: language));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  }

  group('LoginScreen community section', () {
    testWidgets('renders once, as the brand panel cards, on a wide surface', (tester) async {
      setViewport(tester, const Size(1600, 1600));
      await pumpLogin(tester);

      expect(find.byType(CommunityCardGrid), findsOneWidget);
      expect(find.byKey(communityDocsKey), findsOneWidget);
      expect(find.byType(CommunityChipRow), findsNothing, reason: 'the wide layout shows the grid, not the chips');
    });

    testWidgets('renders once, as the chips below the form, on a narrow surface', (tester) async {
      setViewport(tester, kPhoneViewport);
      await pumpLogin(tester);

      expect(find.byType(CommunityChipRow), findsOneWidget);
      expect(find.byKey(communityDocsKey), findsOneWidget);
      expect(find.byType(CommunityCardGrid), findsNothing, reason: 'the phone layout shows the chips, not the grid');
    });
  });

  group('LoginScreen brand panel', () {
    // 1024 px is the narrowest width that shows the brand panel. The test font is wider than the real one, which
    // stands in for a larger text scale.
    testWidgets('lays out without overflow at the desktop breakpoint', (tester) async {
      setViewport(tester, const Size(1024, 1600));
      await pumpLogin(tester);

      expect(tester.takeException(), isNull);
    });

    // The panel speaks to someone signing in to LibreDB, not to a developer choosing a starter project.
    testWidgets('describes LibreDB, not the template it grew from', (tester) async {
      setViewport(tester, const Size(1600, 1600));
      await pumpLogin(tester);

      expect(find.text('Your databases,\nin your pocket.'), findsOneWidget);
      expect(find.text('Organization sign-in'), findsOneWidget);
      expect(find.text('No passwords on the phone'), findsOneWidget);
      expect(find.text('Browse and query'), findsOneWidget);
      for (final templateText in ['Flutter 3.47.7', 'Core Layers', 'BLoC Ready', 'Clean Architecture', 'Platforms']) {
        expect(find.text(templateText), findsNothing, reason: templateText);
      }
    });
  });

  group('LoginScreen identity on a phone', () {
    testWidgets('names the product and says what it does, instead of greeting a return visit', (tester) async {
      // The app has no onboarding flow, so this screen is the whole first-run experience. "Welcome back" assumes a
      // visit that has not happened, and AppConstants.appName appears only in the brand panel, which needs >= 1024.
      setViewport(tester, kPhoneViewport);
      await pumpLogin(tester);

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Reach the databases LibreDB Studio grants you, from your phone.'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      expect(find.text(_wideSubtitle), findsNothing);
    });

    testWidgets('keeps the desktop heading, whose brand panel already carries the identity', (tester) async {
      setViewport(tester, const Size(1440, 900));
      await pumpLogin(tester);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text(_wideSubtitle), findsOneWidget);
    });

    testWidgets('announces the heading as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      setViewport(tester, kPhoneViewport);
      await pumpLogin(tester);

      expect(
        tester.getSemantics(find.text(AppConstants.appName)),
        matchesSemantics(label: AppConstants.appName, isHeader: true),
      );
      semantics.dispose();
    });
  });

  group('LoginScreen - Turkish', () {
    testWidgets('shows the single sign-on page and the brand panel in Turkish', (tester) async {
      setViewport(tester, const Size(1440, 900));
      await pumpLogin(tester, language: 'tr');

      for (final text in [
        'Tekrar hoş geldiniz',
        _wideSubtitleTr,
        'Veritabanlarınız\ncebinizde.',
        "LibreDB Studio'nun size açtığı veritabanlarına telefonunuzdan ulaşın.",
        'Kurum hesabıyla giriş',
        'Telefonda parola yok',
        'Göz atın ve sorgulayın',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byTooltip('Koyu temaya geç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('single sign-on', () {
    final ssoButton = find.byKey(loginButtonSsoKey);

    /// Pumps the app at [viewport], a phone unless a test is about the wide layout. It used to hardcode
    /// 1600x1600, so 32 of this file's tests certified `_desktopLayout` while the app ships on phones.
    Future<void> pumpOidcApp(
      WidgetTester tester,
      AppDependencies dependencies, {
      String language = 'en',
      Size viewport = kPhoneViewport,
    }) async {
      setViewport(tester, viewport);
      await tester.pumpWidget(App(language: language, dependencies: dependencies));
      await tester.pumpAndSettle();
    }

    GoRouter routerFromApp(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

    String location(WidgetTester tester) => routerFromApp(tester).state.uri.toString();

    // Records every location asked of the router from now on, before its redirect runs, so a test sees where the login
    // page sends a sign-in even when the router then sends it elsewhere.
    List<String> recordRequestedLocations(WidgetTester tester) {
      final provider = routerFromApp(tester).routeInformationProvider;
      final requested = <String>[];
      void record() => requested.add(provider.value.uri.toString());
      provider.addListener(record);
      addTearDown(() => provider.removeListener(record));
      return requested;
    }

    SsoAutoRedirectGate gate(WidgetTester tester) =>
        tester.element(find.byType(MaterialApp)).read<SsoAutoRedirectGate>();

    // Signs out as the user does: Logout in the user menu, then Yes in the confirmation dialog.
    Future<void> logOut(WidgetTester tester) async {
      await selectFromUserMenu(tester, Icons.logout);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
    }

    testWidgets('shows only the single sign-on button', (tester) async {
      await pumpOidcApp(tester, OidcDependencies(ScriptedOidcClient()));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in with SSO'), findsOneWidget);
      expect(find.text(_phoneSubtitle), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'no password or code field');
      expect(find.byType(CommunityChipRow), findsOneWidget);
      expect(find.byKey(loginButtonPlatformKey), findsNothing);
      expect(find.text(_studioHelper), findsNothing);
      expect(find.text(_platformHelper), findsNothing);
    });

    for (final (rejection, outcome, message) in [
      ('an unreachable provider', const OidcSignInFailed(OidcFailure.discovery), _discoveryMessage),
      ('an error answer', const OidcSignInFailed(OidcFailure.failed), _failedMessage),
      (
        'a provider certificate that matches no pin',
        const OidcSignInFailed(OidcFailure.untrustedCertificate),
        _insecureConnectionMessage,
      ),
      (
        'an ID token with no subject',
        OidcSignedIn(tokens: signedIn.tokens, claims: const {'iss': 'https://id.example.com/realms/demo'}),
        _failedMessage,
      ),
    ]) {
      testWidgets('says why for $rejection and keeps the button', (tester) async {
        final client = ScriptedOidcClient(outcomes: [outcome]);
        await pumpOidcApp(tester, OidcDependencies(client));

        await tester.tap(ssoButton);
        await tester.pumpAndSettle();

        expect(client.signIns, 1);
        expect(find.text(message), findsOneWidget);
        expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNotNull);
        expect(location(tester), ApplicationRoutesConstants.login);
      });
    }

    // Only Studio decides whether the account may use the app: GET /api/auth/me answers after the provider sign-in.
    for (final (refusal, error, message) in [
      ('a 401 without a code', const AuthError('Unauthorized'), _refusedMessage),
      ('a 403 BEARER_NO_ROLE', AuthError('refused', code: AppErrorCode.studioAccountHasNoRole.key), _noRoleMessage),
      (
        'a certificate that matches no pin',
        NetworkError('blocked', code: AppErrorCode.networkCertInvalid.key),
        _insecureConnectionMessage,
      ),
    ]) {
      testWidgets('says why Studio refused the account for $refusal, stores nothing and keeps the button', (
        tester,
      ) async {
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client, studio: RefusingStudio(error)));

        await tester.tap(ssoButton);
        await tester.pumpAndSettle();

        expect(client.signIns, 1);
        expect(find.text(message), findsOneWidget);
        expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNotNull);
        expect(location(tester), ApplicationRoutesConstants.login);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.jwtToken.key), isNull);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.refreshToken.key), isNull);
      });
    }

    // A startup step that throws signs the user out with authOidcFailed, which the router hands to the page.
    testWidgets('shows a startup sign-in error until the first tap, and nothing while the sign-in runs', (
      tester,
    ) async {
      await storeExpiredSession();
      final answer = Completer<OidcSignInOutcome>();
      final client = ScriptedOidcClient(outcomes: [answer.future]);
      await pumpOidcApp(tester, OidcDependencies(client, rotation: ThrowingRotation()));
      expect(find.text(_failedMessage), findsOneWidget);

      await tester.tap(ssoButton);
      // The spinner runs until the provider answers, so the frames are pumped one by one.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.descendant(of: ssoButton, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(find.text(_failedMessage), findsNothing);

      answer.complete(const OidcSignInCancelled());
      await tester.pumpAndSettle();

      expect(find.text(_failedMessage), findsNothing);
      expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNotNull);
    });

    testWidgets('a misconfigured build announces its error to a screen reader', (tester) async {
      // The error appears without a navigation or a focus change, so without a live region VoiceOver and TalkBack
      // never speak it: a blind user gets no button and no reason. This is the only screen such a build ever shows.
      final semantics = tester.ensureSemantics();

      await pumpOidcApp(
        tester,
        const AppDependencies(
          appConfig: AppConfig.test(),
          authMode: OidcMisconfiguredAuthMode('OIDC_ISSUER is required'),
        ),
      );

      expect(
        tester.getSemantics(find.text(_configMessage)),
        matchesSemantics(label: _configMessage, isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('a misconfigured build says so and shows no button', (tester) async {
      await pumpOidcApp(
        tester,
        const AppDependencies(
          appConfig: AppConfig.test(),
          authMode: OidcMisconfiguredAuthMode('OIDC_ISSUER is required'),
        ),
      );

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(_configMessage), findsOneWidget);
      expect(ssoButton, findsNothing);
      expect(find.byType(TextField), findsNothing, reason: 'no password sign-in to fall back to');
    });

    testWidgets('a misconfigured build with a Platform target shows no button either', (tester) async {
      await pumpOidcApp(
        tester,
        const AppDependencies(
          appConfig: AppConfig.test(),
          authMode: OidcMisconfiguredAuthMode('OIDC_ISSUER is required'),
        ),
      );

      expect(tester.element(find.byType(LoginScreen)).read<AppConfig>().platform, isA<PlatformConfigured>());
      expect(find.text(_configMessage), findsOneWidget);
      expect(ssoButton, findsNothing);
      expect(find.byKey(loginButtonPlatformKey), findsNothing);
    });

    testWidgets('shows the button in Turkish', (tester) async {
      await pumpOidcApp(tester, OidcDependencies(ScriptedOidcClient()), language: 'tr');

      expect(find.widgetWithText(FilledButton, 'SSO ile giriş yap'), findsOneWidget);
      expect(find.text(_phoneSubtitleTr), findsOneWidget);
    });

    testWidgets('a tap signs in and opens the connection list', (tester) async {
      final client = ScriptedOidcClient();
      await pumpOidcApp(tester, OidcDependencies(client));

      await tester.tap(ssoButton);
      await tester.pumpAndSettle();

      expect(client.signIns, 1);
      expect(find.byType(ResponsiveScaffold), findsOneWidget);
      expect(location(tester), ApplicationRoutesConstants.home);
    });

    testWidgets('a safe returnUrl is where the sign-in lands', (tester) async {
      await pumpOidcApp(tester, OidcDependencies(ScriptedOidcClient()));
      routerFromApp(tester).go('${ApplicationRoutesConstants.login}?returnUrl=%2Fsettings');
      await tester.pumpAndSettle();

      await tester.tap(ssoButton);
      await tester.pumpAndSettle();

      expect(location(tester), ApplicationRoutesConstants.settings);
    });

    testWidgets('a returnUrl of /login or with a control character lands on /', (tester) async {
      await pumpOidcApp(tester, OidcDependencies(ScriptedOidcClient()));

      for (final returnUrl in ['%2Flogin', '%2Fsettings%07']) {
        routerFromApp(tester).go('${ApplicationRoutesConstants.login}?returnUrl=$returnUrl');
        await tester.pumpAndSettle();
        await tester.tap(ssoButton);
        await tester.pumpAndSettle();

        expect(location(tester), ApplicationRoutesConstants.home, reason: returnUrl);
        await logOut(tester);
      }
    });

    group('two entries', () {
      final platformButton = find.byKey(loginButtonPlatformKey);

      /// The fill the button actually paints, read off the `Material` a `ButtonStyleButton` builds, so the
      /// assertion survives the theme resolving the style rather than the widget carrying it.
      Color paintedFill(WidgetTester tester, Finder button) =>
          tester.widget<Material>(find.descendant(of: button, matching: find.byType(Material)).first).color!;

      // The two ways in used to be the same FilledButton, so nothing on the page said which one an ordinary user
      // wants. Studio is the ordinary way in and keeps the filled, primary treatment; Platform is for admins and
      // steps back to the quiet outlined one. Both still sign in, and both still span the column.
      testWidgets('Studio reads as the primary action and Platform steps back to a quiet button', (tester) async {
        await pumpOidcApp(tester, OidcDependencies(ScriptedOidcClient(), platform: _withPlatform));

        final cs = Theme.of(tester.element(find.byType(LoginScreen))).colorScheme;

        expect(tester.widget(ssoButton), isA<FilledButton>(), reason: 'Studio is the page primary action');
        expect(
          tester.widget(platformButton),
          isA<OutlinedButton>(),
          reason: 'Platform is the admin path and must not carry the primary weight',
        );
        expect(tester.widget(platformButton), isNot(isA<FilledButton>()));
        expect(paintedFill(tester, ssoButton), cs.primary, reason: 'the primary fill comes from the scheme');
        expect(
          paintedFill(tester, platformButton),
          isNot(cs.primary),
          reason: 'equal fills are exactly what made the two buttons indistinguishable',
        );
        expect(find.widgetWithText(FilledButton, 'Sign in to Platform'), findsNothing);
        expect(tester.getSize(ssoButton).width, tester.getSize(platformButton).width);
      });

      testWidgets('a build with a Platform target shows Studio, then Platform, each with its helper text', (
        tester,
      ) async {
        await pumpOidcApp(tester, OidcDependencies(ScriptedOidcClient(), platform: _withPlatform));

        expect(find.widgetWithText(FilledButton, 'Sign in to Studio'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Sign in to Platform'), findsOneWidget);
        expect(find.text('Sign in with SSO'), findsNothing);
        expect(find.text(_studioHelper), findsOneWidget);
        expect(find.text(_platformHelper), findsOneWidget);
        expect(tester.getTopLeft(ssoButton).dy, lessThan(tester.getTopLeft(platformButton).dy));
        expect(tester.getSize(ssoButton).width, tester.getSize(platformButton).width);
      });

      testWidgets('shows both entries in Turkish', (tester) async {
        await pumpOidcApp(tester, OidcDependencies(ScriptedOidcClient(), platform: _withPlatform), language: 'tr');

        expect(find.widgetWithText(FilledButton, "Studio'ya giriş yap"), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, "Platform'a giriş yap"), findsOneWidget);
        expect(
          find.text('Platform yöneticileri için. İlk Platform girişiniz lisansın bir yönetici koltuğunu kullanır.'),
          findsOneWidget,
        );
      });

      testWidgets('the Platform entry signs in to Platform and opens the Platform home', (tester) async {
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client, platform: _withPlatform));

        final requested = recordRequestedLocations(tester);

        await tester.tap(platformButton);
        await tester.pumpAndSettle();

        expect(client.signIns, 1);
        expect(find.byType(PlatformShell), findsOneWidget);
        expect(location(tester), ApplicationRoutesConstants.platformHome);
        expect(requested, isNot(contains(ApplicationRoutesConstants.home)));
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'platform');
      });

      testWidgets('the Studio entry signs in to Studio and opens the connection list', (tester) async {
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client, platform: _withPlatform));

        await tester.tap(ssoButton);
        await tester.pumpAndSettle();

        expect(client.signIns, 1);
        expect(find.byType(ResponsiveScaffold), findsOneWidget);
        expect(location(tester), ApplicationRoutesConstants.home);
        expect(await FlutterSecureStorageAdapter().read(SecureStorageKeys.sessionTarget.key), 'studio');
      });

      testWidgets('while a sign-in runs both buttons are disabled and only the tapped one spins', (tester) async {
        final answer = Completer<OidcSignInOutcome>();
        final client = ScriptedOidcClient(outcomes: [answer.future]);
        await pumpOidcApp(tester, OidcDependencies(client, platform: _withPlatform));

        await tester.tap(platformButton);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.descendant(of: platformButton, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
        expect(find.descendant(of: ssoButton, matching: find.byType(CircularProgressIndicator)), findsNothing);
        expect(tester.widget<ButtonStyleButton>(platformButton).onPressed, isNull);
        expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNull);

        answer.complete(const OidcSignInCancelled());
        await tester.pumpAndSettle();

        expect(tester.widget<ButtonStyleButton>(platformButton).onPressed, isNotNull);
        expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNotNull);
        expect(client.signIns, 1);
      });

      testWidgets('a Platform refusal stays on the login page, says why, stores nothing and opens no refusal page', (
        tester,
      ) async {
        final platform = RefusingPlatform(AuthError('refused', code: AppErrorCode.platformAdminRoleRequired.key));
        await pumpOidcApp(
          tester,
          OidcDependencies(ScriptedOidcClient(), platform: _withPlatform, platformIdentity: platform),
        );

        await tester.tap(platformButton);
        await tester.pumpAndSettle();

        expect(platform.fetches, 1);
        expect(find.text(_adminRoleRequiredMessage), findsOneWidget);
        expect(location(tester), ApplicationRoutesConstants.login);
        expect(find.byType(PlatformShell), findsNothing);
        expect(
          tester.element(find.byType(LoginScreen)).read<PlatformAccountRefusalCubit>().state,
          const PlatformAccountAccepted(),
        );
        for (final key in [
          SecureStorageKeys.jwtToken,
          SecureStorageKeys.refreshToken,
          SecureStorageKeys.sessionTarget,
        ]) {
          expect(await FlutterSecureStorageAdapter().read(key.key), isNull, reason: key.key);
        }
        expect(tester.widget<ButtonStyleButton>(platformButton).onPressed, isNotNull);
        expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNotNull);
      });

      for (final (signIn, returnUrl, landing) in [
        ('Platform', '%2Fsettings', ApplicationRoutesConstants.platformHome),
        ('Platform', '%2Fplatform%2Fconnections', ApplicationRoutesConstants.platformConnections),
        ('Studio', '%2Fplatform%2Fconnections', ApplicationRoutesConstants.home),
        ('Studio', '%2Fsettings', ApplicationRoutesConstants.settings),
      ]) {
        testWidgets('a $signIn sign-in with returnUrl $returnUrl lands on $landing', (tester) async {
          await pumpOidcApp(tester, OidcDependencies(ScriptedOidcClient(), platform: _withPlatform));
          routerFromApp(tester).go('${ApplicationRoutesConstants.login}?returnUrl=$returnUrl');
          await tester.pumpAndSettle();

          final requested = recordRequestedLocations(tester);

          await tester.tap(signIn == 'Platform' ? platformButton : ssoButton);
          await tester.pumpAndSettle();

          expect(location(tester), landing);
          // The page itself never asks for the other target's route, so the router's own guard is not what keeps it.
          final other = signIn == 'Platform' ? SessionTarget.studio : SessionTarget.platform;
          expect(requested, contains(landing));
          expect(requested.where((path) => ApplicationRoutesConstants.belongsTo(other, path)), isEmpty);
        });
      }

      group('reachability', () {
        final studioRetry = find.byKey(loginUnreachableRetryStudioKey);
        final platformRetry = find.byKey(loginUnreachableRetryPlatformKey);

        testWidgets('Studio down and Platform up: only the Studio entry is disabled, and Platform signs in', (
          tester,
        ) async {
          final client = ScriptedOidcClient();
          final studio = ScriptedLiveness(answer: networkDown);
          final platform = ScriptedLiveness();
          await pumpOidcApp(
            tester,
            OidcDependencies(client, platform: _withPlatform, studioStatus: studio, platformStatus: platform),
          );

          expect(find.byType(StudioUnreachablePage), findsNothing);
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNull);
          expect(find.text(studioDownMessage), findsOneWidget);
          expect(studioRetry, findsOneWidget);
          expect(tester.widget<ButtonStyleButton>(platformButton).onPressed, isNotNull);
          expect(find.text(platformDownMessage), findsNothing);
          expect(platformRetry, findsNothing);
          expect(platform.checks, 1);

          await tester.tap(platformButton);
          await tester.pumpAndSettle();

          expect(client.signIns, 1);
          expect(find.byType(PlatformShell), findsOneWidget);
          expect(find.byType(StudioUnreachablePage), findsNothing);
        });

        testWidgets('Platform down and Studio up: only the Platform entry is disabled', (tester) async {
          await pumpOidcApp(
            tester,
            OidcDependencies(
              ScriptedOidcClient(),
              platform: _withPlatform,
              platformStatus: ScriptedLiveness(answer: networkDown),
            ),
          );

          expect(tester.widget<ButtonStyleButton>(platformButton).onPressed, isNull);
          expect(find.text(platformDownMessage), findsOneWidget);
          expect(platformRetry, findsOneWidget);
          expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNotNull);
          expect(find.text(studioDownMessage), findsNothing);
          expect(studioRetry, findsNothing);
          expect(find.byType(PlatformUnreachablePage), findsNothing);
        });

        testWidgets('both down: both entries are disabled, each with its notice', (tester) async {
          await pumpOidcApp(
            tester,
            OidcDependencies(
              ScriptedOidcClient(),
              platform: _withPlatform,
              studioStatus: ScriptedLiveness(answer: networkDown),
              platformStatus: ScriptedLiveness(answer: networkDown),
            ),
          );

          expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNull);
          expect(tester.widget<ButtonStyleButton>(platformButton).onPressed, isNull);
          expect(find.text(studioDownMessage), findsOneWidget);
          expect(find.text(platformDownMessage), findsOneWidget);
          expect(tester.getTopLeft(find.text(studioDownMessage)).dy, lessThan(tester.getTopLeft(platformButton).dy));
          expect(
            tester.getTopLeft(find.text(platformDownMessage)).dy,
            greaterThan(tester.getTopLeft(platformButton).dy),
          );
        });

        for (final retried in SessionTarget.values) {
          testWidgets('Retry on the ${retried.name} entry asks only that server again', (tester) async {
            final studio = ScriptedLiveness(answer: networkDown);
            final platform = ScriptedLiveness(answer: networkDown);
            await pumpOidcApp(
              tester,
              OidcDependencies(
                ScriptedOidcClient(),
                platform: _withPlatform,
                studioStatus: studio,
                platformStatus: platform,
              ),
            );
            expect((studio.checks, platform.checks), (1, 1));
            final (asked, other) = switch (retried) {
              SessionTarget.studio => (studio, platform),
              SessionTarget.platform => (platform, studio),
            };
            asked.answer = const Success(null);

            await tester.tap(retried == SessionTarget.studio ? studioRetry : platformRetry);
            await tester.pumpAndSettle();

            expect((asked.checks, other.checks), (2, 1));
            final (button, otherButton) = retried == SessionTarget.studio
                ? (ssoButton, platformButton)
                : (platformButton, ssoButton);
            expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
            expect(tester.widget<ButtonStyleButton>(otherButton).onPressed, isNull);
            expect(find.text(retried == SessionTarget.studio ? studioDownMessage : platformDownMessage), findsNothing);
            expect(
              find.text(retried == SessionTarget.studio ? platformDownMessage : studioDownMessage),
              findsOneWidget,
            );
          });
        }

        testWidgets('shows the notices in Turkish', (tester) async {
          await pumpOidcApp(
            tester,
            OidcDependencies(
              ScriptedOidcClient(),
              platform: _withPlatform,
              studioStatus: ScriptedLiveness(answer: networkDown),
              platformStatus: ScriptedLiveness(answer: networkDown),
            ),
            language: 'tr',
          );

          expect(find.text('Studio yanıt vermiyor.'), findsOneWidget);
          expect(find.text('Platform yanıt vermiyor.'), findsOneWidget);
        });
      });

      testWidgets('with the automatic redirect on, two entries never launch the provider and leave the gate open', (
        tester,
      ) async {
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client, autoRedirect: true, platform: _withPlatform));

        expect(client.signIns, 0);
        expect(gate(tester).isOpen, isTrue);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(platformButton, findsOneWidget);
      });
    });

    // As on 3777948: the Studio gate covers the single entry, and Platform is never asked.
    testWidgets(
      'a build without a Platform target covers the login page while Studio is down and never asks Platform',
      (tester) async {
        final platform = ScriptedLiveness();
        await pumpOidcApp(
          tester,
          OidcDependencies(
            ScriptedOidcClient(),
            studioStatus: ScriptedLiveness(answer: networkDown),
            platformStatus: platform,
          ),
        );

        expect(find.byType(StudioUnreachablePage), findsOneWidget);
        expect(find.text(studioDownMessage, skipOffstage: false), findsNothing);
        expect(platform.checks, 0);
      },
    );

    testWidgets('a restored Platform session in a build without Platform says so and does not redirect', (
      tester,
    ) async {
      TestEnv.authenticate(target: SessionTarget.platform);
      final client = ScriptedOidcClient();
      await pumpOidcApp(tester, OidcDependencies(client, autoRedirect: true));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(_platformNotConfiguredMessage), findsOneWidget);
      expect(client.signIns, 0);
      expect(find.byKey(loginButtonPlatformKey), findsNothing);
    });

    group('automatic redirect', () {
      testWidgets('signs in once on a cold start', (tester) async {
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client, autoRedirect: true));

        expect(client.signIns, 1);
        expect(find.byType(ResponsiveScaffold), findsOneWidget);
        expect(gate(tester).isOpen, isFalse);
      });

      testWidgets('does not run after a startup sign-in error', (tester) async {
        await storeExpiredSession();
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client, autoRedirect: true, rotation: ThrowingRotation()));

        expect(client.signIns, 0);
        expect(find.text(_failedMessage), findsOneWidget);
      });

      // There is no `onboardingPending` parameter on LoginScreen, and there should not be: under the route design it
      // would always be false, so it would be dead weight. This is the test that parameter was really about. If
      // anyone later moves the introduction into the page instead of in front of it, a build that signs in on its
      // own sends a first-time user to the identity provider without ever showing the introduction, and this fails.
      testWidgets('does not run while the introduction is still ahead of the user', (tester) async {
        await TestEnv.onboardingUnseen();
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client, autoRedirect: true));

        expect(client.signIns, 0);
        expect(location(tester), ApplicationRoutesConstants.welcome);
        expect(find.byType(LoginScreen), findsNothing);
      });

      testWidgets('does not run when it is turned off', (tester) async {
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client));

        expect(client.signIns, 0);
        expect(ssoButton, findsOneWidget);
      });

      testWidgets('does not run when the login page shows again after a logout', (tester) async {
        final client = ScriptedOidcClient();
        await pumpOidcApp(tester, OidcDependencies(client, autoRedirect: true));
        expect(find.byType(ResponsiveScaffold), findsOneWidget);

        await logOut(tester);

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(client.signIns, 1);
      });

      testWidgets('after a cancel, keeps the gate closed and the button signs in again', (tester) async {
        final client = ScriptedOidcClient(outcomes: [const OidcSignInCancelled()]);
        await pumpOidcApp(tester, OidcDependencies(client, autoRedirect: true));
        expect(client.signIns, 1);
        expect(gate(tester).isOpen, isFalse);
        expect(tester.widget<ButtonStyleButton>(ssoButton).onPressed, isNotNull);

        await tester.tap(ssoButton);
        await tester.pumpAndSettle();

        expect(client.signIns, 2);
        expect(find.byType(ResponsiveScaffold), findsOneWidget);
      });

      testWidgets('after an error, keeps the gate closed and the error on the page', (tester) async {
        final client = ScriptedOidcClient(outcomes: [const OidcSignInFailed(OidcFailure.discovery)]);
        await pumpOidcApp(tester, OidcDependencies(client, autoRedirect: true));

        expect(client.signIns, 1);
        expect(gate(tester).isOpen, isFalse);
        expect(find.text(_discoveryMessage), findsOneWidget);
      });
    });
  });
}
