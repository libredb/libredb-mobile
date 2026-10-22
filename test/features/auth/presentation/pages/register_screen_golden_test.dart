import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/register_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/test_env.dart';
import '../../../../support/golden_app.dart';

void main() {
  setUpAll(() => TestEnv.autoReset = false);

  late MockRegisterBloc registerBloc;

  setUp(() {
    registerBloc = MockRegisterBloc();

    whenListen(registerBloc, Stream<RegisterState>.empty(), initialState: const RegisterInitialState());
    when(() => registerBloc.state).thenReturn(const RegisterInitialState());
  });

  Widget buildScreen({bool dark = false}) {
    final screen = MultiBlocProvider(
      providers: [BlocProvider<RegisterBloc>.value(value: registerBloc)],
      child: RegisterScreen(),
    );
    return goldenRoutedScreen(screen, dark: dark);
  }

  goldenTest(
    'RegisterScreen — light',
    fileName: 'register_screen_light',
    pumpBeforeTest: pumpOnce,
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'initial',
          child: SizedBox.fromSize(size: kGoldenScreenSize, child: buildScreen(dark: false)),
        ),
      ],
    ),
  );

  goldenTest(
    'RegisterScreen — dark',
    fileName: 'register_screen_dark',
    pumpBeforeTest: pumpOnce,
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'initial',
          child: SizedBox.fromSize(size: kGoldenScreenSize, child: buildScreen(dark: true)),
        ),
      ],
    ),
  );
}
