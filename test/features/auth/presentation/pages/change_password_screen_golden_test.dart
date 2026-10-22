import 'package:alchemist/alchemist.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/change_password_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/change_password_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/test_env.dart';
import '../../../../support/golden_app.dart';

void main() {
  setUpAll(() => TestEnv.autoReset = false);

  late MockChangePasswordBloc changePasswordBloc;

  setUp(() {
    changePasswordBloc = MockChangePasswordBloc();

    whenListen(
      changePasswordBloc,
      Stream<ChangePasswordState>.empty(),
      initialState: const ChangePasswordInitialState(),
    );
    when(() => changePasswordBloc.state).thenReturn(const ChangePasswordInitialState());
  });

  Widget buildScreen({bool dark = false}) {
    final screen = MultiBlocProvider(
      providers: [BlocProvider<ChangePasswordBloc>.value(value: changePasswordBloc)],
      child: ChangePasswordScreen(),
    );
    return goldenRoutedScreen(screen, dark: dark);
  }

  goldenTest(
    'ChangePasswordScreen — light',
    fileName: 'change_password_screen_light',
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
    'ChangePasswordScreen — dark',
    fileName: 'change_password_screen_dark',
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
