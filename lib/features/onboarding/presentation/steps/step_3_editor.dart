import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';
import 'package:libredb_mobile/shared/utils/source_highlighter.dart';

/// The third screen of the introduction: the editor on a production connection.
///
/// A counting statement types itself behind a blinking caret, the Run pill brightens and presses itself, the answer
/// counts up to 128,440 beside `1 row · 41 ms` — and then the statement becomes a `delete`, and the app's own write
/// confirmation rises in place of the answer. The second beat is the point of the screen: the one thing this product
/// does that no database client does by itself is refuse to run a write until the person has said the connection's
/// name out loud.
///
/// **It draws its hero and nothing else.** The caption, the headline, the body, the counter, the progress and the
/// controls are the chassis's, and **nothing here is tappable**: the Run pill is the affordance the animation presses,
/// and the confirmation's Cancel and Run are the picture of a sheet, not the sheet. Next is the only control.
///
/// **The statement cannot come out doubled.** Every frame is `statement.substring(0, n)` of one constant, so the only
/// text the editor can ever hold is a prefix of the finished statement; an audit of the HTML prototype this is built
/// from caught it holding `select select count(*) fromfrom orders;` for 1.3 seconds, because it typed four segments
/// and appended each one twice.
///
/// **The colours are roles, not a picture of the prototype.** The same audit measured the prototype's confirmation
/// header at 1.90:1 — `error` used as a fill with white on it, which in the dark scheme is white on `#FCA5A5`. In this
/// design system `error` is ink: the header fills with `errorContainer` and writes in `onErrorContainer`, which
/// measures 5.91:1 light and 8.80:1 dark.
class Step3Editor extends StatefulWidget {
  const Step3Editor({super.key});

  /// The demo connection. A production one, which is why the confirmation asks for its name.
  static const connectionName = 'orders-prod';

  /// What types itself, and what it is replaced by. Both are the whole text at every frame, never a fragment.
  static const statement = 'select count(*) from orders;';
  static const deleteStatement = 'delete from orders where id = 8842;';

  /// Why the confirmation asks, in the words the app's own check would use.
  ///
  /// `InterimWriteCheck` is the check, and it lives in the SQL editor's feature, which this one may not import —
  /// `import_guard_test.dart` holds cross-feature imports at zero. So the word and the line are written here and
  /// `step_3_editor_test.dart` runs the real check over [deleteStatement] and fails when they drift from what it
  /// flags. The sheet still says what the app says; the assertion moved from the widget to the test.
  static const flaggedWord = 'DELETE';
  static const flaggedLine = 1;

  /// The answer: the count, and the shape of the line beside the Run pill.
  static const answer = 128440;
  static const answerRows = 1;
  static const answerMilliseconds = 41;

  // The beats, as `PLAY[2]` of the prototype times them, measured from the frame the screen is shown. Each one is a
  // moment; the length of what moves at that moment is an `AppDurations` token, so the motion belongs to the design
  // system even where the choreography belongs to the prototype.

  /// The caret appears and the first character lands.
  static const typeStartsAt = Duration(milliseconds: 250);

  /// How long the whole statement takes to type: `AppDurations.media` twice, about 29 ms a character.
  static const typingTakes = Duration(milliseconds: 800);

  /// The Run pill brightens from quiet to primary over [AppDurations.normal].
  static const runLitAt = Duration(milliseconds: 1300);

  /// The pill presses itself: down and back up over [AppDurations.fast] each way.
  static const pressesAt = Duration(milliseconds: 1690);

  /// The pill's line goes to the pending mark.
  static const pendingAt = Duration(milliseconds: 1750);

  /// The answer arrives, and the count climbs over [countsUpOver].
  static const answersAt = Duration(milliseconds: 2300);
  static const countsUpOver = Duration(milliseconds: 900);

  /// The statement becomes the delete.
  static const deletesAt = Duration(milliseconds: 3450);

  /// The answer gives way to the write confirmation.
  static const sheetRisesAt = Duration(milliseconds: 3950);

  /// The whole timeline, long enough for the confirmation's own entrance to finish inside it. The screen plays once
  /// and stops, on its finished state.
  static const plays = Duration(milliseconds: 4350);

  /// The editor's text, so a test can read exactly what the screen holds rather than what it looks like.
  static const statementKey = ValueKey('ob_step3_statement');

  /// The confirmation's header, whose fill is the one an audit measured.
  static const sheetHeaderKey = ValueKey('ob_step3_sheet_header');

  @override
  State<Step3Editor> createState() => _Step3EditorState();
}

class _Step3EditorState extends State<Step3Editor> with SingleTickerProviderStateMixin {
  /// How far the caret, the result and the confirmation come in from the trailing edge as they arrive.
  static const _slidesIn = AppSpacing.xl;

  /// How deep the Run pill presses itself.
  static const _pressDepth = 0.06;

  /// Half a blink. The caret is on for one of these and off for the next.
  static const _blink = AppDurations.media;

  late final AnimationController _play = AnimationController(vsync: this, duration: Step3Editor.plays);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With animations off the screen is its finished state from the first frame: the statement is the delete and the
    // confirmation is up, which is what the screen is for. Nothing is waiting to be tapped, so nothing is lost.
    if (MediaQuery.disableAnimationsOf(context)) {
      _play.stop();
      _play.value = 1;
    } else if (!_play.isAnimating && _play.value == 0) {
      _play.forward();
    }
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  /// Where the timeline stands. The controller runs linearly, so its value is the clock.
  Duration get _elapsed => Step3Editor.plays * _play.value;

  /// How far into [beat]'s own animation of length [over] the timeline is, eased by the design system's entrance.
  double _eased(Duration at, Duration beat, Duration over) {
    final into = at - beat;
    if (into <= Duration.zero) return 0;
    final fraction = (into.inMicroseconds / over.inMicroseconds).clamp(0.0, 1.0);
    return AppDurations.easeOut.transform(fraction);
  }

  /// What the editor holds at [at]: a prefix of [Step3Editor.statement] while it types, the whole of it once it has,
  /// and [Step3Editor.deleteStatement] from the beat the statement changes.
  String _typed(Duration at) {
    if (at >= Step3Editor.deletesAt) return Step3Editor.deleteStatement;
    final into = at - Step3Editor.typeStartsAt;
    if (into <= Duration.zero) return '';
    final fraction = (into.inMicroseconds / Step3Editor.typingTakes.inMicroseconds).clamp(0.0, 1.0);
    return Step3Editor.statement.substring(0, (fraction * Step3Editor.statement.length).floor());
  }

  /// Whether the caret is drawn at [at]: from the first character until the pill presses, blinking.
  bool _caretShows(Duration at) {
    if (at < Step3Editor.typeStartsAt || at >= Step3Editor.pressesAt) return false;
    return ((at - Step3Editor.typeStartsAt).inMicroseconds ~/ _blink.inMicroseconds).isEven;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: AppTypography.mono) ?? const TextStyle();

    return AnimatedBuilder(
      animation: _play,
      builder: (context, _) {
        final at = _elapsed;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _editor(at, colors, mono),
            const SizedBox(height: AppSpacing.sm),
            _runBar(at, s, colors, mono),
            const SizedBox(height: AppSpacing.sm),
            if (at >= Step3Editor.sheetRisesAt)
              _arriving(at, Step3Editor.sheetRisesAt, _confirmation(s, theme, colors, mono))
            else if (at >= Step3Editor.answersAt)
              _arriving(at, Step3Editor.answersAt, _result(at, s, theme, colors)),
          ],
        );
      },
    );
  }

  /// Fades [child] in and slides it from the trailing edge, the one entrance every arriving piece of the screen uses.
  Widget _arriving(Duration at, Duration beat, Widget child) {
    final progress = _eased(at, beat, AppDurations.media);
    return Opacity(
      opacity: progress,
      child: Transform.translate(offset: Offset(_slidesIn * (1 - progress), 0), child: child),
    );
  }

  /// The editor box: the statement, coloured by the editor's own highlighter, and the caret beside it.
  Widget _editor(Duration at, ColorScheme colors, TextStyle mono) {
    final typed = _typed(at);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: Text.rich(_coloured(typed, colors, mono), key: Step3Editor.statementKey)),
            // The caret is its own box rather than a character in the span, so the span holds the statement and
            // nothing else and a test reads the text the editor really has.
            SizedBox(
              width: AppSpacing.xs,
              height: mono.fontSize,
              child: ColoredBox(color: _caretShows(at) ? colors.primary : Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  /// The Run pill and the line beside it: quiet, then bright, then pressed, then answered.
  Widget _runBar(Duration at, S s, ColorScheme colors, TextStyle mono) {
    final lit = _eased(at, Step3Editor.runLitAt, AppDurations.normal);
    final fill = Color.lerp(colors.surfaceContainerHighest, colors.primary, lit);
    final ink = Color.lerp(colors.onSurfaceVariant, colors.onPrimary, lit);
    return Row(
      children: [
        Transform.scale(
          scale: 1 - _pressDepth * _press(at),
          child: DecoratedBox(
            decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Text(
                s.sql_editor_run,
                style: mono.copyWith(color: ink, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // The line beside the pill takes the room the pill leaves and wraps inside it. A `Spacer` and a bare `Text`
        // here overflowed the hero by 80 pt at a text scale of 3.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: switch (at) {
              _ when at >= Step3Editor.answersAt => Text(
                s.ob3_meta(
                  s.sql_history_rows(Step3Editor.answerRows),
                  s.sql_history_duration(Step3Editor.answerMilliseconds),
                ),
                textAlign: TextAlign.end,
                style: mono.copyWith(color: colors.onSurfaceVariant),
              ),
              // A mark rather than a word: the pending state of a demo is not a sentence the app has to translate.
              _ when at >= Step3Editor.pendingAt => Icon(
                Icons.more_horiz,
                size: AppSizes.iconMd,
                color: colors.onSurfaceVariant,
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }

  /// How far the pill is pressed at [at], 0 at rest and 1 at the bottom of the press.
  double _press(Duration at) {
    final into = at - Step3Editor.pressesAt;
    final whole = AppDurations.fast * 2;
    if (into <= Duration.zero || into >= whole) return 0;
    final fraction = into.inMicroseconds / whole.inMicroseconds;
    return AppDurations.easeOut.transform(fraction < 0.5 ? fraction * 2 : (1 - fraction) * 2);
  }

  /// The answer: the column name the statement asked for, and the number climbing to it.
  Widget _result(Duration at, S s, ThemeData theme, ColorScheme colors) {
    final climbed = _eased(at, Step3Editor.answersAt, Step3Editor.countsUpOver);
    final number = NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: colors.surfaceContainerHighest),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Text(
                s.ob3_count,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: AppTypography.mono,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              number.format((Step3Editor.answer * climbed).round()),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: AppTypography.mono,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The write confirmation, drawn the way the app's own sheet draws itself: the title over an `errorContainer`
  /// header, every reason the check gives in words, the refusal line for a read-only grant, the production prompt,
  /// the field the connection's name is typed in, and Cancel beside a Run that cannot run yet.
  Widget _confirmation(S s, ThemeData theme, ColorScheme colors, TextStyle mono) {
    final body = theme.textTheme.bodySmall;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.error),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            key: Step3Editor.sheetHeaderKey,
            decoration: BoxDecoration(color: colors.errorContainer),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: AppSizes.iconLg, color: colors.onErrorContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      s.write_confirm_title,
                      style: theme.textTheme.titleSmall?.copyWith(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  s.write_confirm_reason_may_write_at(Step3Editor.flaggedWord, Step3Editor.flaggedLine),
                  style: body?.copyWith(color: colors.onSurfaceVariant),
                ),
                Text(s.write_confirm_production_prompt, style: body?.copyWith(color: colors.error)),
                Text(s.write_confirm_read_grant, style: body?.copyWith(color: colors.error)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      s.write_confirm_name_label(Step3Editor.connectionName),
                      style: mono.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
                // A `Wrap`, as the app's own sheet uses for the same two labels: side by side while they fit, and Run
                // on a second line when they do not. A `Row` here overflowed by 272 pt at a text scale of 3.
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(s.write_confirm_cancel, style: body?.copyWith(color: colors.onSurfaceVariant)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        child: Text(
                          s.write_confirm_run,
                          style: body?.copyWith(color: colors.onErrorContainer, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [statement] coloured by the app's own keyword rules.
  ///
  /// `SourceHighlighter` is the highlighting itself and lives in `shared/`, so nothing about SQL is decided here; the
  /// three lines of colour below are the token-to-role map, which this repository keeps at each call site (the SQL
  /// editor's text controller and the object browser's source viewer each hold the same one) because the import guard
  /// holds cross-feature imports at zero. The roles are the same roles, so a demo statement is coloured exactly as a
  /// real one.
  TextSpan _coloured(String statement, ColorScheme colors, TextStyle mono) => TextSpan(
    style: mono,
    children: [
      for (final token in SourceHighlighter.forLanguage(_sql).tokens(statement))
        TextSpan(
          text: token.text,
          style: switch (token.kind) {
            SourceTokenKind.plain => mono,
            SourceTokenKind.keyword => mono.copyWith(color: colors.onPrimaryContainer, fontWeight: FontWeight.w600),
            SourceTokenKind.string => mono.copyWith(color: colors.tertiary),
            SourceTokenKind.number => mono.copyWith(color: colors.secondary),
            SourceTokenKind.comment => mono.copyWith(color: colors.onSurfaceVariant, fontStyle: FontStyle.italic),
          },
        ),
    ],
  );

  /// The language the demo connection speaks, as `SourceHighlighter` names it.
  static const _sql = 'sql';
}
