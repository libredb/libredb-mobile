import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:libredb_mobile/shared/models/target_reachability.dart';
import 'package:libredb_mobile/shared/widgets/target_reachability_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/test_env.dart';
import '../../../../support/golden_app.dart';

void main() {
  setUpAll(() => TestEnv.autoReset = false);

  late MockLoginBloc loginBloc;

  setUp(() {
    loginBloc = MockLoginBloc();

    whenListen(loginBloc, Stream<LoginState>.empty(), initialState: const LoginInitialState());
    when(() => loginBloc.state).thenReturn(const LoginInitialState());
  });

  Widget buildScreen({
    required AuthMode authMode,
    PlatformTargetConfig platform = const PlatformNotConfigured(),
    bool dark = false,
    TargetReachability studio = TargetReachability.unknown,
    TargetReachability platformReach = TargetReachability.unknown,
  }) {
    final screen = MultiBlocProvider(
      providers: [
        RepositoryProvider<AuthMode>.value(value: authMode),
        RepositoryProvider<AppConfig>.value(
          value: AppConfig(
            environment: Environment.mock,
            apiBaseUrl: null,
            certificatePins: const <String>[],
            idleTimeout: null,
            platform: platform,
          ),
        ),
        BlocProvider<LoginBloc>.value(value: loginBloc),
        RepositoryProvider<ProjectLinks>.value(value: const ProjectLinks()),
      ],
      child: TargetReachabilityScope(
        studio: studio,
        platform: platformReach,
        onRetry: (_) {},
        child: const LoginScreen(),
      ),
    );
    return goldenScreen(screen, dark: dark);
  }

  // The single sign-on page, which sends the user to the provider only on a tap. Pumped past the page's 600 ms
  // fade-in, whose first frame is blank, so the image shows the page.
  goldenTest(
    'LoginScreen: single sign-on, light',
    fileName: 'login_screen_sso_light',
    pumpBeforeTest: (tester) => tester.pump(const Duration(milliseconds: 600)),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'initial',
          child: SizedBox.fromSize(
            size: kGoldenScreenSize,
            child: buildScreen(
              authMode: OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app')),
            ),
          ),
        ),
      ],
    ),
  );

  // A build with a Platform target: Studio and Platform as two entries of equal weight, each with its helper text.
  goldenTest(
    'LoginScreen: Studio and Platform entries, light',
    fileName: 'login_screen_two_entries_light',
    pumpBeforeTest: (tester) => tester.pump(const Duration(milliseconds: 600)),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'initial',
          child: SizedBox.fromSize(
            size: kGoldenScreenSize,
            child: buildScreen(
              authMode: OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app')),
              platform: const PlatformConfigured(),
            ),
          ),
        ),
      ],
    ),
  );

  // The dark variants of the two above. Only the light ones were rendered, so every colour this page draws in the
  // dark — the surface, the entry buttons, the community chips, the version label — was unguarded (#377).
  goldenTest(
    'LoginScreen: single sign-on, dark',
    fileName: 'login_screen_sso_dark',
    pumpBeforeTest: (tester) => tester.pump(const Duration(milliseconds: 600)),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'initial',
          child: SizedBox.fromSize(
            size: kGoldenScreenSize,
            child: buildScreen(
              authMode: OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app')),
              dark: true,
            ),
          ),
        ),
      ],
    ),
  );

  goldenTest(
    'LoginScreen: Studio and Platform entries, dark',
    fileName: 'login_screen_two_entries_dark',
    pumpBeforeTest: (tester) => tester.pump(const Duration(milliseconds: 600)),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'initial',
          child: SizedBox.fromSize(
            size: kGoldenScreenSize,
            child: buildScreen(
              authMode: OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app')),
              platform: const PlatformConfigured(),
              dark: true,
            ),
          ),
        ),
      ],
    ),
  );

  // A build whose OIDC defines are missing or wrong. The page says what an administrator has to fix and offers no
  // sign-in at all, which is the one state where the entry is gone rather than disabled.
  goldenTest(
    'LoginScreen: a misconfigured build, light',
    fileName: 'login_screen_misconfigured_light',
    pumpBeforeTest: (tester) => tester.pump(const Duration(milliseconds: 600)),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'initial',
          child: SizedBox.fromSize(
            size: kGoldenScreenSize,
            child: buildScreen(
              authMode: const OidcMisconfiguredAuthMode('OIDC_ISSUER is empty, so the build names no provider.'),
            ),
          ),
        ),
      ],
    ),
  );

  // Studio does not answer. The entry is disabled and carries the notice and its Retry, which is the state a user on
  // a bad network meets and which no image has covered.
  goldenTest(
    'LoginScreen: Studio unreachable, light',
    fileName: 'login_screen_unreachable_light',
    pumpBeforeTest: (tester) => tester.pump(const Duration(milliseconds: 600)),
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'initial',
          child: SizedBox.fromSize(
            size: kGoldenScreenSize,
            child: buildScreen(
              authMode: OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.com'), clientId: 'app')),
              platform: const PlatformConfigured(),
              studio: TargetReachability.unreachable,
              platformReach: TargetReachability.reachable,
            ),
          ),
        ),
      ],
    ),
  );
}
