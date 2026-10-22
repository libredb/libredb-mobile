import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
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

  Widget buildScreen({required AuthMode authMode, bool dark = false}) {
    final screen = MultiBlocProvider(
      providers: [
        RepositoryProvider<AuthMode>.value(value: authMode),
        BlocProvider<LoginBloc>.value(value: loginBloc),
        RepositoryProvider<ProjectLinks>.value(value: const ProjectLinks()),
      ],
      child: const LoginScreen(),
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
}
