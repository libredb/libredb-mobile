import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/forgot_password_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/test_env.dart';
import '../../../../support/golden_app.dart';

void main() {
  setUpAll(() => TestEnv.autoReset = false);

  late MockForgotPasswordBloc forgotPasswordBloc;

  setUp(() {
    forgotPasswordBloc = MockForgotPasswordBloc();

    whenListen(
      forgotPasswordBloc,
      Stream<ForgotPasswordState>.empty(),
      initialState: const ForgotPasswordInitialState(),
    );
    when(() => forgotPasswordBloc.state).thenReturn(const ForgotPasswordInitialState());
  });

  Widget buildScreen({bool dark = false}) {
    final screen = MultiBlocProvider(
      providers: [BlocProvider<ForgotPasswordBloc>.value(value: forgotPasswordBloc)],
      child: ForgotPasswordScreen(),
    );
    return goldenRoutedScreen(screen, dark: dark);
  }

  goldenTest(
    'ForgotPasswordScreen — light',
    fileName: 'forgot_password_screen_light',
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
    'ForgotPasswordScreen — dark',
    fileName: 'forgot_password_screen_dark',
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
