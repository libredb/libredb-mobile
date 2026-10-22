@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:libredb_mobile/app/shell/sign_out_progress_barrier.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

void main() {
  // A sign-out waits for Studio's record for up to three seconds after the confirmed tap, and a second tap meanwhile
  // must not reach the page.
  testWidgets('a blocking progress indicator shows while the sign-out runs, and goes when it is done', (tester) async {
    final authRepository = MockIAuthRepository();
    final logout = Completer<Result<void>>();
    when(() => authRepository.logout()).thenAnswer((_) => logout.future);
    // The provider closes it when the test unmounts the tree.
    final bloc = SignOutBloc(logoutUseCase: LogoutUseCase(authRepository));
    var pageTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: BlocProvider(
          create: (_) => bloc,
          child: SignOutProgressBarrier(
            child: Scaffold(
              body: Center(
                child: TextButton(onPressed: () => pageTaps++, child: const Text('page')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(signOutProgressIndicatorKey), findsNothing);
    await tester.tap(find.text('page'));
    expect(pageTaps, 1);

    bloc.add(const SignOutRequested());
    await tester.pump();

    expect(find.byKey(signOutProgressIndicatorKey), findsOneWidget);
    await tester.tap(find.text('page'), warnIfMissed: false);
    expect(pageTaps, 1, reason: 'the barrier takes the taps meant for the page below it');

    logout.complete(const Success(null));
    await tester.pump();

    expect(bloc.state, isA<SignOutDone>());
    expect(find.byKey(signOutProgressIndicatorKey), findsNothing);
    await tester.tap(find.text('page'));
    expect(pageTaps, 2);
  });
}
