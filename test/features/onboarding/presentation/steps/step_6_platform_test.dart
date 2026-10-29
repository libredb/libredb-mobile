@Tags(['widget'])
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/features/onboarding/presentation/steps/step_6_platform.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The sixth screen: who allowed the statement of the third screen, and where it was written down.
///
/// Two things here are the whole payoff of the deck and both of them are order claims, so both are measured rather
/// than looked at:
///
/// * **The log reads newest first**, the order the real Audit tab uses. An audit caught the prototype rendering
///   `Just now → 21 min → 12 min` — the right rows in the wrong order, which is exactly the defect a screenshot
///   cannot show. The rows are therefore read off their painted positions, top to bottom, and their ages must
///   ascend.
/// * **The log writes itself in**, oldest first, so that each new line pushes the older ones down and the newest
///   lands on top. That is the opposite insertion order from the reading order, and the two are asserted apart:
///   at the first log beat only the oldest row has been drawn.
///
/// The refused row carries `[redacted]` where its statement would be, and the note under the card is the app's own
/// `platform_audit_statement_redacted`, not a sentence written again for the deck.
///
/// The clock is fixed, because the grant line reads a date.
void main() {
  /// The instant the deck is read at. Fixed so the grant's date is a value the test can state.
  final now = DateTime(2026, 10, 29, 14, 30);

  /// A frame at [elapsed] of the step's timeline, pumped from the first frame so every beat before it has run.
  Future<S> pumpStep(
    WidgetTester tester, {
    Duration elapsed = Duration.zero,
    Locale locale = const Locale('en'),
    bool disableAnimations = false,
    Size viewport = const Size(390, 844),
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        locale: locale,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Step6Platform()),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
      ),
    );
    if (elapsed > Duration.zero) await tester.pump(elapsed);
    return S.of(tester.element(find.byType(Step6Platform)));
  }

  Finder row(String key) => find.byKey(ValueKey(key));

  /// The painted height of a log row's slot. A row that has not been written in yet has none.
  double drawnHeight(WidgetTester tester, String key) => tester.getSize(row(key)).height;

  double topOf(WidgetTester tester, String key) => tester.getTopLeft(row(key)).dy;

  void expectInside(WidgetTester tester, String key, Finder text, {required String what}) {
    expect(
      find.descendant(of: row(key), matching: text),
      findsOneWidget,
      reason: what,
    );
  }

  testWidgets('the audit log reads newest first, the order the Audit tab uses', (tester) async {
    late final S s;
    await withClock(Clock.fixed(now), () async {
      s = await pumpStep(tester, elapsed: Step6Beats.whole);
    });

    expect(topOf(tester, 'ob6-event-0'), lessThan(topOf(tester, 'ob6-event-1')));
    expect(topOf(tester, 'ob6-event-1'), lessThan(topOf(tester, 'ob6-event-2')));
    expectInside(
      tester,
      'ob6-event-0',
      find.textContaining(s.platform_audit_time_just_now),
      what: 'the newest line is not on top',
    );
    expectInside(
      tester,
      'ob6-event-1',
      find.textContaining(s.platform_audit_time_minutes_ago(12)),
      what: 'the middle line is not the 12-minute-old one',
    );
    expectInside(
      tester,
      'ob6-event-2',
      find.textContaining(s.platform_audit_time_minutes_ago(21)),
      what: 'the oldest line is not at the bottom',
    );
  });

  testWidgets('the statement the person ran on the third screen is the top row, and it is theirs', (tester) async {
    late final S s;
    await withClock(Clock.fixed(now), () async {
      s = await pumpStep(tester, elapsed: Step6Beats.whole);
    });

    expectInside(
      tester,
      'ob6-event-0',
      find.text('select count(*) from orders'),
      what: 'the statement of the third screen is not the top line of the log',
    );
    expectInside(tester, 'ob6-event-0', find.text(s.ob6_you), what: 'the top line is not named as the reader’s own');
    expectInside(
      tester,
      'ob6-event-0',
      find.textContaining(s.platform_audit_duration(41)),
      what: 'the top line does not carry the 41 ms the third screen answered in',
    );
    expectInside(
      tester,
      'ob6-event-0',
      find.textContaining(s.platform_audit_row_count(1)),
      what: 'the top line does not carry its row count',
    );
  });

  testWidgets('the refused line carries the redaction where its statement would be', (tester) async {
    late final S s;
    await withClock(Clock.fixed(now), () async {
      s = await pumpStep(tester, elapsed: Step6Beats.whole);
    });

    expectInside(tester, 'ob6-event-2', find.text(s.ob6_redacted), what: 'the refused line shows no redaction');
    expectInside(
      tester,
      'ob6-event-2',
      find.text(s.platform_audit_status_refused),
      what: 'the refused line is not marked refused',
    );
    expect(
      find.text(s.platform_audit_statement_redacted),
      findsOneWidget,
      reason: "nothing says the connection's capture setting withheld it, in the app's own words",
    );
    expectInside(
      tester,
      'ob6-event-1',
      find.text(s.platform_audit_status_success),
      what: 'the colleague’s UPDATE is not marked successful',
    );
  });

  testWidgets('the grant that let the person read orders-prod names its granter', (tester) async {
    late final S s;
    await withClock(Clock.fixed(now), () async {
      s = await pumpStep(tester, elapsed: Step6Beats.whole);
    });
    final granted = DateFormat.yMMMd('en').add_Hm().format(now.subtract(const Duration(days: 2)));

    expectInside(tester, 'ob6-grant-0', find.text(s.ob6_you), what: 'the reader’s own grant is not named as theirs');
    expectInside(
      tester,
      'ob6-grant-0',
      find.text(s.platform_grants_granted_by('ayse', granted)),
      what: 'the grant does not say who granted it and when',
    );
    expectInside(
      tester,
      'ob6-grant-0',
      find.text(s.platform_grants_level_read),
      what: 'the grant that let them read is not a read grant',
    );
    expectInside(
      tester,
      'ob6-grant-1',
      find.text(s.platform_grants_level_write),
      what: 'the colleague’s write grant is not a write grant',
    );
  });

  testWidgets('the outcome and the level are the app’s words, not English in a Turkish deck', (tester) async {
    late final S s;
    await withClock(Clock.fixed(now), () async {
      s = await pumpStep(tester, elapsed: Step6Beats.whole, locale: const Locale('tr'));
    });

    expect(s.platform_audit_status_refused, 'Reddedildi');
    expect(s.platform_grants_level_read, 'Okuma');
    expect(find.text(s.platform_audit_status_success), findsNWidgets(2), reason: 'two of the three lines ran');
    expect(find.text(s.platform_audit_status_refused), findsOneWidget);
    expect(find.text(s.platform_grants_level_read), findsOneWidget);
    expect(find.text(s.platform_grants_level_write), findsOneWidget);
    expect(find.text(s.platform_audit_time_just_now), findsNothing, reason: 'the time is inside the details line');
    expect(find.textContaining(s.platform_audit_time_just_now), findsOneWidget);
  });

  testWidgets('the log writes itself in oldest first, so the newest lands on top', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pumpStep(tester, elapsed: Step6Beats.firstLine + Step6Beats.arrival);
    });

    expect(drawnHeight(tester, 'ob6-event-2'), greaterThan(0), reason: 'the oldest line is not written in first');
    expect(drawnHeight(tester, 'ob6-event-1'), 0, reason: 'the middle line arrived before the oldest finished');
    expect(drawnHeight(tester, 'ob6-event-0'), 0, reason: 'the newest line arrived first, so nothing pushed it down');
  });

  testWidgets('nothing in the step answers a finger', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pumpStep(tester, elapsed: Step6Beats.whole);
    });

    expect(find.descendant(of: find.byType(Step6Platform), matching: find.byType(InkWell)), findsNothing);
    expect(find.descendant(of: find.byType(Step6Platform), matching: find.byType(GestureDetector)), findsNothing);
  });

  testWidgets('with animations off the whole record is on screen at the first frame', (tester) async {
    late final S s;
    await withClock(Clock.fixed(now), () async {
      s = await pumpStep(tester, disableAnimations: true);
    });

    for (final key in ['ob6-grant-0', 'ob6-grant-1', 'ob6-event-0', 'ob6-event-1', 'ob6-event-2']) {
      expect(drawnHeight(tester, key), greaterThan(0), reason: '$key is not drawn with animations off');
    }
    expect(find.text(s.platform_audit_statement_redacted), findsOneWidget);
    expect(topOf(tester, 'ob6-event-0'), lessThan(topOf(tester, 'ob6-event-2')));
  });

  /// The grant is one row, not a stack.
  ///
  /// The prototype draws it as `.g{display:flex;align-items:center}`: the holder and `orders-prod · <when>` in a
  /// column on the left, the level beside them on the right, 48pt tall. Drawn as four stacked blocks instead it
  /// comes to about 116 on a real phone, and the two grants plus the three audit rows then overflow the hero by
  /// 257pt — measured on the emulator, where the overflow stripe lay across the headline and both controls.
  ///
  /// The claim is the arrangement, not a height: a height measured under `flutter test` is a claim about Ahem,
  /// whose glyphs are square ems, rather than about the product font.
  testWidgets('a grant puts its level beside the holder, not under the whole stack', (tester) async {
    final l10n = await pumpStep(tester, elapsed: Step6Beats.whole);

    // 'mert' appears twice on this screen — once as the holder of the write grant and once as the user of an
    // audit line — so the holder is found inside the card the level is in rather than by its text alone.
    final levelFinder = find.text(l10n.platform_grants_level_write);
    final card = find.ancestor(of: levelFinder, matching: find.byType(AppCard)).first;
    final holder = tester.getRect(find.descendant(of: card, matching: find.text('mert')));
    final level = tester.getRect(levelFinder);

    expect(
      level.center.dy,
      closeTo(holder.center.dy, holder.height),
      reason: 'the level sits at ${level.center.dy.toStringAsFixed(1)} against a holder centred at '
          '${holder.center.dy.toStringAsFixed(1)} — it is under the holder, not beside it',
    );
    expect(level.left, greaterThan(holder.right), reason: 'the level is not to the right of the holder');
  });

}
