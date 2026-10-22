@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/check_studio_liveness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/application/usecases/read_studio_readiness_usecase.dart';
import 'package:libredb_mobile/features/studio_status/presentation/pages/studio_unreachable_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_button.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

void main() {
  late MockIStudioStatusRepository repository;

  setUp(() {
    repository = MockIStudioStatusRepository();
    when(() => repository.liveness()).thenAnswer((_) async => const Success(null));
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    String? host = 'studio.example.test',
    AppError error = const NetworkError('No Internet connection'),
    bool retrying = false,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: BlocProvider(
          create: (_) => StudioStatusBloc(
            checkLivenessUseCase: CheckStudioLivenessUseCase(repository),
            readReadinessUseCase: ReadStudioReadinessUseCase(repository),
          ),
          child: StudioUnreachablePage(host: host, error: error, retrying: retrying),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says that Studio cannot be reached, names the configured host and offers a retry', (tester) async {
    await pumpPage(tester);

    expect(find.text("Can't reach Studio"), findsOneWidget);
    expect(find.textContaining('studio.example.test'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
  });

  // Nothing about the session went wrong, so the page never talks about signing in.
  testWidgets('never words it as a sign-in or session problem', (tester) async {
    await pumpPage(tester);

    expect(find.textContaining(RegExp('sign|session', caseSensitive: false)), findsNothing);
  });

  testWidgets('leaves out the host when none is configured', (tester) async {
    await pumpPage(tester, host: null);

    expect(find.text("Can't reach Studio"), findsOneWidget);
    expect(find.textContaining('Studio address'), findsNothing);
  });

  testWidgets('adds the translated reason when the error has one, such as an untrusted certificate', (tester) async {
    await pumpPage(tester, error: NetworkError('handshake', code: AppErrorCode.networkCertInvalid.key));

    expect(find.textContaining('could not be verified as secure'), findsOneWidget);
    expect(find.textContaining('handshake'), findsNothing);
  });

  testWidgets('Retry asks for a liveness check', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(AppButton));
    await tester.pump();

    verify(() => repository.liveness()).called(1);
  });

  testWidgets('shows the retry as busy while the check runs', (tester) async {
    await pumpPage(tester, retrying: true);

    expect(tester.widget<AppButton>(find.byType(AppButton)).isLoading, isTrue);
  });

  testWidgets('speaks the app language', (tester) async {
    await pumpPage(tester, locale: const Locale('tr'));

    expect(find.text("Studio'ya ulaşılamıyor"), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Tekrar Dene'), findsOneWidget);
  });
}
