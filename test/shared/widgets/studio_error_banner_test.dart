@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

import '../../support/printed_lines.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  localizationsDelegates: const [
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: S.delegate.supportedLocales,
  locale: locale,
  home: Scaffold(body: child),
);

/// The retry button of the banner.
Finder get _retryButton => find.widgetWithText(OutlinedButton, 'Retry');

bool _enabled(WidgetTester tester, Finder button) => tester.widget<ButtonStyleButton>(button).onPressed != null;

AppError _error(AppErrorCode code, {String message = 'server words'}) => ServerError(message, code: code.key);

void main() {
  group('StudioErrorBanner for a rate limit', () {
    RateLimitedError rateLimited([Duration? retryAfter]) =>
        RateLimitedError('Too many requests', code: AppErrorCode.studioRateLimited.key, retryAfter: retryAfter);

    testWidgets('counts down from retryAfter and enables the retry action at zero', (tester) async {
      var available = 0;
      var retried = 0;
      await tester.pumpWidget(
        _app(
          StudioErrorBanner(
            error: rateLimited(const Duration(seconds: 3)),
            onRetry: () => retried++,
            onRetryAvailable: () => available++,
          ),
        ),
      );

      expect(find.text('Too many requests in a short time. Wait a moment and try again.'), findsOneWidget);
      expect(find.text('You can try again in 3 s.'), findsOneWidget);
      expect(_enabled(tester, _retryButton), isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('You can try again in 2 s.'), findsOneWidget);
      expect(_enabled(tester, _retryButton), isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('You can try again in 1 s.'), findsOneWidget);
      expect(available, 0);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('You can try again in'), findsNothing);
      expect(_enabled(tester, _retryButton), isTrue);
      expect(available, 1);
      expect(retried, 0, reason: 'the banner never retries on its own');

      await tester.pump(const Duration(seconds: 5));
      expect(available, 1, reason: 'the countdown stops at zero');

      await tester.tap(_retryButton);
      expect(retried, 1);
    });

    testWidgets('without retryAfter the retry action is available at once', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_app(StudioErrorBanner(error: rateLimited(), onRetry: () => retried++)));

      expect(find.textContaining('You can try again in'), findsNothing);
      expect(_enabled(tester, _retryButton), isTrue);
      await tester.tap(_retryButton);
      expect(retried, 1);
    });

    testWidgets('a new rate limit starts a new countdown', (tester) async {
      await tester.pumpWidget(_app(StudioErrorBanner(error: rateLimited(const Duration(seconds: 2)), onRetry: () {})));
      await tester.pump(const Duration(seconds: 2));
      expect(_enabled(tester, _retryButton), isTrue);

      await tester.pumpWidget(_app(StudioErrorBanner(error: rateLimited(const Duration(seconds: 4)), onRetry: () {})));
      expect(find.text('You can try again in 4 s.'), findsOneWidget);
      expect(_enabled(tester, _retryButton), isFalse);
    });

    testWidgets('leaving the screen during the countdown leaves no timer behind', (tester) async {
      await tester.pumpWidget(_app(StudioErrorBanner(error: rateLimited(const Duration(seconds: 30)))));
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      // The test framework fails a test that ends with a pending timer.
    });
  });

  testWidgets('governance unavailable says Studio is retrying', (tester) async {
    await tester.pumpWidget(_app(StudioErrorBanner(error: _error(AppErrorCode.studioGovernanceUnavailable))));

    expect(find.text('Studio cannot check your access right now. Retrying automatically.'), findsOneWidget);
    expect(_retryButton, findsNothing, reason: 'no retry action is given');
  });

  group('database auth', () {
    late List<MethodCall> platformCalls;

    setUp(() {
      platformCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('shows the message and the fixStatement as copyable monospace text', (tester) async {
      const error = AuthError('refused', code: 'studio.database_auth', fixStatement: 'GRANT ROLE R TO USER U');
      await tester.pumpWidget(_app(const StudioErrorBanner(error: error)));

      expect(
        find.text("The database refused the connection's credentials. Ask your administrator to check them."),
        findsOneWidget,
      );
      final statement = tester.widget<SelectableText>(find.widgetWithText(SelectableText, 'GRANT ROLE R TO USER U'));
      expect(statement.style?.fontFamily, 'monospace');

      await tester.tap(find.byTooltip('Copy statement'));
      await tester.pump();

      final copy = platformCalls.singleWhere((call) => call.method == 'Clipboard.setData');
      expect((copy.arguments as Map)['text'], 'GRANT ROLE R TO USER U');
      expect(find.text('Statement copied'), findsOneWidget);
    });

    testWidgets('without a fixStatement shows the message only', (tester) async {
      const error = AuthError('refused', code: 'studio.database_auth');
      await tester.pumpWidget(_app(const StudioErrorBanner(error: error)));

      expect(find.byType(SelectableText), findsNothing);
      expect(find.byTooltip('Copy statement'), findsNothing);
    });

    testWidgets('the fixStatement of a Studio answer reaches the banner', (tester) async {
      final error = studioError(
        UnauthorizedException(
          'body',
          statusCode: 401,
          errorCode: 'AUTH_ERROR',
          serverMessage: 'password authentication failed',
          fixStatement: 'GRANT ROLE R TO USER U',
        ),
      );
      await tester.pumpWidget(_app(StudioErrorBanner(error: error)));

      expect(find.widgetWithText(SelectableText, 'GRANT ROLE R TO USER U'), findsOneWidget);
    });
  });

  group('the other Studio errors show their translated message', () {
    final cases = <AppErrorCode, String>{
      AppErrorCode.studioConnectionNotAvailable: 'This connection is not available to you.',
      AppErrorCode.studioTimeout: 'The database did not answer in time.',
      AppErrorCode.studioDatabaseUnreachable: 'The database could not be reached. Try again in a moment.',
    };
    for (final MapEntry(key: code, value: message) in cases.entries) {
      testWidgets(code.key, (tester) async {
        var retried = 0;
        await tester.pumpWidget(_app(StudioErrorBanner(error: _error(code), onRetry: () => retried++)));

        expect(find.text(message), findsOneWidget);
        expect(find.text('server words'), findsNothing);
        await tester.tap(_retryButton);
        expect(retried, 1);
      });
    }

    testWidgets('an error without a known code shows the generic message', (tester) async {
      await tester.pumpWidget(_app(const StudioErrorBanner(error: UnknownError('boom'))));

      expect(find.text('boom'), findsNothing);
      expect(find.byType(StudioErrorBanner), findsOneWidget);
    });
  });

  testWidgets('the banner has a semantics label and an icon, not color alone', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(StudioErrorBanner(error: _error(AppErrorCode.studioTimeout))));

    expect(find.bySemanticsLabel('Error: The database did not answer in time.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows Turkish when the app is in Turkish', (tester) async {
    await tester.pumpWidget(
      _app(
        StudioErrorBanner(
          error: RateLimitedError(
            'x',
            code: AppErrorCode.studioRateLimited.key,
            retryAfter: const Duration(seconds: 5),
          ),
          onRetry: () {},
        ),
        locale: const Locale('tr'),
      ),
    );

    expect(find.text('5 sn sonra yeniden deneyebilirsiniz.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('never logs the error text of a database error', (tester) async {
    const secret = 'relation "payroll_secret" does not exist';
    final lines = await printedLines(() async {
      await tester.pumpWidget(
        _app(StudioErrorBanner(error: ValidationError(secret, code: AppErrorCode.studioQueryError.key))),
      );
      await tester.pumpWidget(
        _app(StudioErrorBanner(error: AuthError(secret, code: AppErrorCode.studioDatabaseAuth.key))),
      );
    });

    expect(lines.where((line) => line.contains('payroll_secret')), isEmpty);
    expect(find.textContaining('payroll_secret'), findsNothing);
  });

  group('showStudioErrorSnackBar', () {
    Future<void> show(WidgetTester tester, AppError error) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showStudioErrorSnackBar(context, error),
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pump();
    }

    testWidgets('shows the translated message', (tester) async {
      await show(tester, _error(AppErrorCode.studioConnectionNotAvailable));

      expect(
        find.descendant(of: find.byType(SnackBar), matching: find.text('This connection is not available to you.')),
        findsOneWidget,
      );
    });

    testWidgets('says how long a rate limit asks to wait', (tester) async {
      await show(
        tester,
        RateLimitedError('x', code: AppErrorCode.studioRateLimited.key, retryAfter: const Duration(seconds: 12)),
      );

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(
            'Too many requests in a short time. Wait a moment and try again. You can try again in 12 s.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers to copy the fixStatement of a database auth error', (tester) async {
      await show(
        tester,
        const AuthError('refused', code: 'studio.database_auth', fixStatement: 'GRANT ROLE R TO USER U'),
      );

      expect(find.widgetWithText(SnackBarAction, 'Copy statement'), findsOneWidget);
    });

    group('copy action', () {
      const error = AuthError('refused', code: 'studio.database_auth', fixStatement: 'GRANT ROLE R TO USER U');
      late List<MethodCall> platformCalls;

      setUp(() {
        platformCalls = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            platformCalls.add(call);
            return null;
          },
        );
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      Future<void> expectCopied(WidgetTester tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(SnackBarAction, 'Copy statement'));
        await tester.pump();
        await tester.pumpAndSettle();

        final copy = platformCalls.singleWhere((call) => call.method == 'Clipboard.setData');
        expect((copy.arguments as Map)['text'], 'GRANT ROLE R TO USER U');
        expect(find.descendant(of: find.byType(SnackBar), matching: find.text('Statement copied')), findsOneWidget);
      }

      testWidgets('copies the fixStatement and confirms it', (tester) async {
        await show(tester, error);

        await expectCopied(tester);
      });

      testWidgets('still copies after the page that showed the snack bar is popped', (tester) async {
        await tester.pumpWidget(_app(const SizedBox.shrink()));
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const Key('show'),
                    onPressed: () => showStudioErrorSnackBar(context, error),
                    child: const SizedBox(width: 40, height: 40),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('show')));
        await tester.pump();
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('show')), findsNothing, reason: 'the page that showed the snack bar is gone');

        await expectCopied(tester);
      });
    });
  });
}
