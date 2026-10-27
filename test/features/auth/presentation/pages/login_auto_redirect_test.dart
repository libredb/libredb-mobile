@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

/// The automatic redirect as the page performs it, on the page alone.
///
/// `login_screen_test.dart` covers the same ground through the whole `App`, which is where the router and the session
/// belong. This file pumps the page against the four providers its first-frame callback actually reads, so a change
/// to the callback fails here with the callback's own name in the stack rather than inside a routing test (#379).
///
/// What this file deliberately does not try to cover is the page leaving the tree before that callback runs. The
/// page guards it with `mounted`, and no widget test can reach it: `setState` defers an unmount to the next frame,
/// so the page is still mounted at the end of the frame it mounted in, whatever a test does. The guard is held by
/// `test/architecture/post_frame_context_test.dart` instead, which reads the source.
void main() {
  late MockLoginBloc bloc;
  late SsoAutoRedirectGate gate;

  setUp(() {
    bloc = MockLoginBloc();
    when(() => bloc.state).thenReturn(const LoginInitialState());
    gate = SsoAutoRedirectGate();
  });

  /// A build that redirects on its own: `autoRedirect` on, and — through `AppConfig.local`, whose Platform target is
  /// unset — the single entry the redirect needs. `AppConfig.mock` would not do: it carries a Platform target, so it
  /// offers two entries and the page is right to leave the choice to the user.
  final redirecting = OidcAuthMode(
    OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app', autoRedirect: true),
  );
  final notRedirecting = OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app'));

  Future<void> pumpPage(WidgetTester tester, {required AuthMode mode, AppConfig? config}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AuthMode>.value(value: mode),
            RepositoryProvider<AppConfig>.value(value: config ?? const AppConfig.local()),
            RepositoryProvider<SsoAutoRedirectGate>.value(value: gate),
            RepositoryProvider<ProjectLinks>.value(value: const ProjectLinks()),
          ],
          child: BlocProvider<LoginBloc>.value(value: bloc, child: const LoginScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a single-entry build signs in without a tap, and closes the gate', (tester) async {
    await pumpPage(tester, mode: redirecting);

    verify(() => bloc.add(const SsoSignInRequested(target: SessionTarget.studio))).called(1);
    expect(gate.isOpen, isFalse, reason: 'a fired redirect closes the gate for the rest of the run');
  });

  testWidgets('a build that did not ask for it waits for the tap', (tester) async {
    await pumpPage(tester, mode: notRedirecting);

    verifyNever(() => bloc.add(any()));
    expect(gate.isOpen, isTrue, reason: 'a gate is closed by a redirect or a failure, not by a page that showed');
  });

  testWidgets('a two-entry build never redirects, whatever the settings say', (tester) async {
    await pumpPage(tester, mode: redirecting, config: const AppConfig.mock());

    verifyNever(() => bloc.add(any()));
    expect(gate.isOpen, isTrue, reason: 'the user has a choice to make, so the gate stays open for it');
  });

  testWidgets('a gate another page already closed is not reopened', (tester) async {
    gate.close();
    await pumpPage(tester, mode: redirecting);

    verifyNever(() => bloc.add(any()));
  });
}
