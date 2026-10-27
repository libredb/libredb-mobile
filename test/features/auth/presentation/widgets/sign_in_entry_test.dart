@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/sign_in_entry.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/target_reachability.dart';
import 'package:libredb_mobile/shared/widgets/target_reachability_scope.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

/// One way into the app, on its own.
///
/// The behaviour under test is the one the page used to decide by counting siblings: a build with a single entry
/// leaves the unreachable gate to the status page above it, while a build with two gates each entry itself. On the
/// page that was `_entries.length > 1`, so an entry's own behaviour depended on how many others happened to exist,
/// and nothing could reach it without pumping the whole screen. Here it is one flag and two assertions (#379).
void main() {
  late MockLoginBloc bloc;

  setUp(() {
    bloc = MockLoginBloc();
    when(() => bloc.state).thenReturn(const LoginInitialState());
  });

  final retried = <SessionTarget>[];

  Widget buildEntry({
    required bool showsReachability,
    TargetReachability studio = TargetReachability.unreachable,
    String? helper = 'Sign in to Studio',
    SessionTarget target = SessionTarget.studio,
    LoginState state = const LoginInitialState(),
  }) {
    when(() => bloc.state).thenReturn(state);
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: TargetReachabilityScope(
          studio: studio,
          platform: TargetReachability.unreachable,
          onRetry: retried.add,
          child: BlocProvider<LoginBloc>.value(
            value: bloc,
            child: SignInEntry(
              target: target,
              buttonKey: loginButtonSsoKey,
              label: 'Sign in',
              helper: helper,
              showsReachability: showsReachability,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  bool buttonIsEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(loginButtonSsoKey)).onPressed != null;

  group('an entry that does not gate itself', () {
    testWidgets('keeps its button enabled while its server does not answer', (tester) async {
      await tester.pumpWidget(buildEntry(showsReachability: false));
      await tester.pumpAndSettle();

      expect(
        buttonIsEnabled(tester),
        isTrue,
        reason: 'the single entry of a build with one target is gated by the status page, not by itself',
      );
    });

    testWidgets('shows no unreachable notice and no retry', (tester) async {
      await tester.pumpWidget(buildEntry(showsReachability: false));
      await tester.pumpAndSettle();

      expect(
        find.text(S.current.login_unreachable_studio),
        findsNothing,
        reason:
            'an entry that does not act on the check must not report it either; two surfaces saying the same '
            'thing differently is what the flag exists to prevent',
      );
      expect(find.byKey(loginUnreachableRetryStudioKey), findsNothing);
    });
  });

  group('an entry that gates itself', () {
    testWidgets('disables its button and offers a retry while its server does not answer', (tester) async {
      await tester.pumpWidget(buildEntry(showsReachability: true));
      await tester.pumpAndSettle();

      expect(buttonIsEnabled(tester), isFalse);
      expect(find.text(S.current.login_unreachable_studio), findsOneWidget);
      expect(find.byKey(loginUnreachableRetryStudioKey), findsOneWidget);
    });

    testWidgets('asks the server of its own target again', (tester) async {
      retried.clear();
      await tester.pumpWidget(buildEntry(showsReachability: true, target: SessionTarget.platform));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(loginUnreachableRetryPlatformKey));
      await tester.pumpAndSettle();

      expect(retried, [SessionTarget.platform]);
    });

    testWidgets('leaves the button enabled once the server answers', (tester) async {
      await tester.pumpWidget(buildEntry(showsReachability: true, studio: TargetReachability.reachable));
      await tester.pumpAndSettle();

      expect(buttonIsEnabled(tester), isTrue);
      expect(find.text(S.current.login_unreachable_studio), findsNothing);
    });
  });

  testWidgets('an entry with no helper draws no helper line', (tester) async {
    await tester.pumpWidget(buildEntry(showsReachability: false, studio: TargetReachability.reachable, helper: null));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<Text>(find.descendant(of: find.byType(SignInEntry), matching: find.byType(Text)))
          .map((text) => text.data),
      ['Sign in'],
      reason: 'the button label is the only text the entry carries; an empty helper would still be a Text here',
    );
    expect(
      tester.getSize(find.byType(SignInEntry)).height,
      tester.getSize(find.byKey(loginButtonSsoKey)).height,
      reason:
          'the entry is exactly its button — an empty helper would keep the 8 px gap under it and move the '
          'golden that certifies this screen',
    );
  });

  testWidgets('only the running target spins, and every button is disabled while it does', (tester) async {
    await tester.pumpWidget(
      buildEntry(
        showsReachability: false,
        studio: TargetReachability.reachable,
        target: SessionTarget.platform,
        state: const LoginLoadingState(target: SessionTarget.studio),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(buttonIsEnabled(tester), isFalse, reason: 'a sign-in is running, whichever target it belongs to');
    expect(
      find.descendant(of: find.byKey(loginButtonSsoKey), matching: find.byType(CircularProgressIndicator)),
      findsNothing,
      reason: 'the spinner belongs to the entry whose sign-in is running',
    );
  });
}
