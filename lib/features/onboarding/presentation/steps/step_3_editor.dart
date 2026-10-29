import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/syntax_colors.dart';
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
  static const _slidesIn = 22.0;

  /// How deep the Run pill presses itself.
  static const _pressDepth = 0.06;

  /// The most of the run bar the Run pill may take, so the line beside it always keeps the rest.
  ///
  /// The prototype's pill is 89.6 pt of the hero's 318 — 28 per cent — so three fifths is more than twice the room
  /// the pill asks for at the ordinary text size in either language, and nothing there is capped. At an
  /// accessibility text size the label grows past the whole bar, and this is what holds it inside.
  static const _pillShare = 0.6;

  /// The prototype's own measures of this hero, from headless Chrome at 390x844 (`ob.html`, screen 3). None is on the
  /// closed spacing scale and all are this screen's own: `.ed{padding:10px 12px;min-height:52px;border-radius:11px}`,
  /// `.runb{padding:6px 14px}`, `.scal{margin-top:9px;border-radius:11px}`, `.scal .h{padding:6px 11px}`,
  /// `.scal .v{padding:11px;font-size:26px}`, `.sheet .sh{padding:7px 11px}`, `.sheet .sb2{padding:9px 11px}`,
  /// `.typebox{margin:0 11px 9px;padding:6px 8px;border-radius:8px}`, `.sheetacts{gap:7px;padding:0 11px 10px}` and
  /// `.sheetacts span{padding:6px 12px}`.
  static const _editorPadX = 12.0;
  static const _editorPadY = 10.0;
  static const _editorMinHeight = 52.0;
  static const _cardRadius = 11.0;
  static const _gap = 9.0;
  static const _pillPadX = 14.0;
  static const _pillPadY = 6.0;
  static const _headPadX = 11.0;
  static const _answerHeadPadY = 6.0;
  static const _answerPad = 11.0;
  static const _sheetHeadPadY = 7.0;
  static const _sheetPadY = 9.0;
  static const _sheetPadX = 11.0;
  static const _warnGap = 5.0;
  static const _boxPadY = 6.0;
  static const _boxPadX = 8.0;
  static const _actsGap = 7.0;
  static const _actsPadBottom = 10.0;
  static const _actPadX = 12.0;

  /// The type: mono 11 over a 14 line, sans 11 over 1.5 and over a 13 line (the header and the pills), the editor's
  /// 1.7, the answer's 26 over a line of 1, and the tracking of the pill, the answer's header and the number.
  static const _small = 11.0;
  static const _monoLine = 14 / _small;
  static const _sansLine = 1.5;
  static const _tightLine = 13 / _small;
  static const _editorLine = 1.7;
  static const _answerSize = 26.0;
  static const _pillTrackingEm = 0.1;
  static const _headTrackingEm = 0.13;
  static const _answerTrackingEm = -0.02;

  /// How opaque the Run pill is before it is lit, and the confirmation's Run pill at rest: `.runb{opacity:.3}`,
  /// `.sa-r{opacity:.45}`.
  static const _pillRestOpacity = 0.3;
  static const _sheetRunOpacity = 0.45;

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
    final mono =
        theme.textTheme.labelSmall?.copyWith(
          fontFamily: AppTypography.mono,
          fontSize: _small,
          height: _monoLine,
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
          color: colors.onSurface,
        ) ??
        const TextStyle();

    return AnimatedBuilder(
      animation: _play,
      builder: (context, _) {
        final at = _elapsed;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _editor(at, theme, mono),
            const SizedBox(height: AppSpacing.sm),
            _runBar(at, s, colors, mono),
            // The gap is the arriving piece's own margin (`.scal{margin-top:9px}`), so there is none before it comes
            // and the bar sits centred on its own until the answer takes its place.
            if (at >= Step3Editor.sheetRisesAt) ...[
              const SizedBox(height: _gap),
              _arriving(at, Step3Editor.sheetRisesAt, _confirmation(s, theme, mono)),
            ] else if (at >= Step3Editor.answersAt) ...[
              const SizedBox(height: _gap),
              _arriving(at, Step3Editor.answersAt, _result(at, s, theme, mono)),
            ],
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

  /// The editor box: the statement, coloured as the prototype colours it, and the caret beside it.
  Widget _editor(Duration at, ThemeData theme, TextStyle mono) {
    final colors = theme.colorScheme;
    final typed = _typed(at);
    final line = mono.copyWith(height: _editorLine);
    return Container(
      key: const ValueKey('ob3-editor'),
      constraints: const BoxConstraints(minHeight: _editorMinHeight),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: _editorPadX, vertical: _editorPadY),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: Text.rich(_coloured(typed, theme, line), key: Step3Editor.statementKey)),
          // The caret is its own box rather than a character in the span, so the span holds the statement and
          // nothing else and a test reads the text the editor really has. `.caret` is 6 wide and a whole line high.
          SizedBox(
            width: _caretWidth,
            height: _small * _editorLine,
            child: ColoredBox(color: _caretShows(at) ? colors.primary : Colors.transparent),
          ),
        ],
      ),
    );
  }

  /// `meta.textContent='…'`: a punctuation mark, not a sentence, so it is no string of the app's.
  static const _pendingMark = '\u2026';

  /// `.caret{width:6px}`.
  static const _caretWidth = 6.0;

  /// The Run pill and the line beside it: quiet, then bright, then pressed, then answered.
  Widget _runBar(Duration at, S s, ColorScheme colors, TextStyle mono) {
    final lit = _eased(at, Step3Editor.runLitAt, AppDurations.normal);
    // The bar is measured rather than assumed, because the pill is the one thing on this screen that cannot be
    // allowed to ask for its natural width. The line beside it already yields — it is `Expanded` and wraps — but
    // the pill was the row's inflexible child, so `Çalıştır` at a text scale of 3 asked for more than the row had
    // and overflowed to the right by 13 pt in the hero of a 390 pt phone and by 83 pt in the 248 pt hero of a
    // 320 pt one. Capping it here is the one way to bound it without taking room from the line: a `Flexible` pill
    // would split the bar between the two by flex factor, which narrows the line's own box and rewraps it at the
    // ordinary text size, and the prototype's measurement of this screen does not allow that.
    //
    // The `LayoutBuilder` is safe for the same reason the chassis's own one is: `_HeroExtent` answers the page's
    // intrinsic question itself and never puts it to a step.
    final locale = Localizations.localeOf(context);
    return LayoutBuilder(
      builder: (context, bar) => Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: (bar.maxWidth - AppSpacing.sm) * _pillShare),
            child: Transform.scale(
              scale: 1 - _pressDepth * _press(at),
              // `.runb{opacity:.3}` until `.go` lights it: the pill is always the accent, drawn faint.
              child: Opacity(
                opacity: _pillRestOpacity + (1 - _pillRestOpacity) * lit,
                child: Container(
                  key: const ValueKey('ob3-run'),
                  decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  padding: const EdgeInsets.symmetric(horizontal: _pillPadX, vertical: _pillPadY),
                  child: Text(
                    onboardingCapitals(s.sql_editor_run, locale),
                    style: mono.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: _small * _pillTrackingEm,
                    ),
                  ),
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
                  key: const ValueKey('ob3-meta'),
                  textAlign: TextAlign.end,
                  style: mono.copyWith(color: colors.onSurfaceVariant),
                ),
                // `meta.textContent='…'`: the prototype's pending state is the character, not an icon.
                _ when at >= Step3Editor.pendingAt => Text(
                  _pendingMark,
                  style: mono.copyWith(color: colors.onSurfaceVariant),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
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
  Widget _result(Duration at, S s, ThemeData theme, TextStyle mono) {
    final colors = theme.colorScheme;
    final climbed = _eased(at, Step3Editor.answersAt, Step3Editor.countsUpOver);
    final number = NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag());
    return Container(
      key: const ValueKey('ob3-result'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('ob3-result-head'),
            color: colors.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: _headPadX, vertical: _answerHeadPadY),
            child: Text(
              onboardingCapitals(s.ob3_count, Localizations.localeOf(context)),
              style: mono.copyWith(color: colors.onSurfaceVariant, letterSpacing: _small * _headTrackingEm),
            ),
          ),
          Container(
            key: const ValueKey('ob3-result-value'),
            padding: const EdgeInsets.all(_answerPad),
            child: Text(
              number.format((Step3Editor.answer * climbed).round()),
              style: mono.copyWith(
                fontSize: _answerSize,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: _answerSize * _answerTrackingEm,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The write confirmation, drawn the way the prototype draws it: the title over the error fill, the production
  /// prompt, the reason in mono, the refusal line for a read-only grant, the field the connection's name is typed
  /// in, and Cancel beside a Run that cannot run yet.
  ///
  /// The header is `--err-fill` with `--on-err` on it: the error colour with white in the light scope, and the error
  /// container with the text ink in the dark one. The audit that moved this off `error` as a fill measured the dark
  /// scope — white on `#FCA5A5` at 1.90:1 — and the prototype it audited has since made that pair `#3A0F13` with
  /// `#F2F4FB` on it, which is what the dark scope's `errorContainer` and `onSurface` are.
  Widget _confirmation(S s, ThemeData theme, TextStyle mono) {
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final fill = light ? colors.error : colors.errorContainer;
    final onFill = light ? colors.onError : colors.onSurface;
    final sans = theme.textTheme.bodySmall?.copyWith(fontSize: _small, height: _sansLine, letterSpacing: 0);
    return Container(
      key: const ValueKey('ob3-sheet'),
      clipBehavior: Clip.antiAlias,
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
            decoration: BoxDecoration(color: fill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _headPadX, vertical: _sheetHeadPadY),
              child: Text(
                s.write_confirm_title,
                style: sans?.copyWith(color: onFill, fontWeight: FontWeight.w700, height: _tightLine),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sheetPadX, vertical: _sheetPadY),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.write_confirm_production_prompt, style: sans?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: _warnGap),
                Text(
                  s.write_confirm_reason_may_write_at(Step3Editor.flaggedWord, Step3Editor.flaggedLine),
                  style: mono.copyWith(color: colors.error, height: _sansLine),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_sheetPadX, 0, _sheetPadX, _sheetPadY),
            child: Text(s.write_confirm_read_grant, style: sans?.copyWith(color: colors.error)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_sheetPadX, 0, _sheetPadX, _sheetPadY),
            child: Container(
              key: const ValueKey('ob3-typebox'),
              padding: const EdgeInsets.symmetric(horizontal: _boxPadX, vertical: _boxPadY),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(s.write_confirm_name_label(Step3Editor.connectionName), style: mono),
            ),
          ),
          // A `Wrap`, as the app's own sheet uses for the same two labels: side by side while they fit, and Run on a
          // second line when they do not. A `Row` here overflowed by 272 pt at a text scale of 3.
          Padding(
            padding: const EdgeInsets.fromLTRB(_sheetPadX, 0, _sheetPadX, _actsPadBottom),
            child: Wrap(
              spacing: _actsGap,
              runSpacing: AppSpacing.xs,
              children: [
                Container(
                  key: const ValueKey('ob3-cancel'),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: _actPadX, vertical: _pillPadY),
                  child: Text(
                    s.write_confirm_cancel,
                    style: sans?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: _tightLine,
                    ),
                  ),
                ),
                Opacity(
                  opacity: _sheetRunOpacity,
                  // The prototype's two pills sit in a stretching flex row, so the borderless one is as tall as the
                  // bordered one; a transparent border of the same width gives it that without a stretch.
                  child: Container(
                    key: const ValueKey('ob3-go'),
                    decoration: BoxDecoration(
                      color: fill,
                      border: Border.all(color: Colors.transparent),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: _actPadX, vertical: _pillPadY),
                    child: Text(
                      s.write_confirm_run,
                      style: sans?.copyWith(color: onFill, fontWeight: FontWeight.w600, height: _tightLine),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [statement] coloured by the app's own keyword rules, in the prototype's ink.
  ///
  /// `SourceHighlighter` is the highlighting itself and lives in `shared/`, so nothing about SQL is decided here; the
  /// few lines of colour below are the token-to-role map, which this repository keeps at each call site (the SQL
  /// editor's text controller and the object browser's source viewer each hold the same one) because the import guard
  /// holds cross-feature imports at zero. The prototype sets `.k` in its keyword ink at 600 and `.s` in its string
  /// ink, a number being a `.s` there, and leaves everything else in the plain ink.
  TextSpan _coloured(String statement, ThemeData theme, TextStyle mono) {
    final colors = theme.colorScheme;
    final keyword = SyntaxColors.keyword(theme.brightness);
    final string = SyntaxColors.string(theme.brightness);
    return TextSpan(
      style: mono,
      children: [
        for (final token in SourceHighlighter.forLanguage(_sql).tokens(statement))
          TextSpan(
            text: token.text,
            style: switch (token.kind) {
              SourceTokenKind.plain => mono,
              SourceTokenKind.keyword => mono.copyWith(color: keyword, fontWeight: FontWeight.w600),
              SourceTokenKind.string || SourceTokenKind.number => mono.copyWith(color: string),
              SourceTokenKind.comment => mono.copyWith(color: colors.onSurfaceVariant, fontStyle: FontStyle.italic),
            },
          ),
      ],
    );
  }

  /// The language the demo connection speaks, as `SourceHighlighter` names it.
  static const _sql = 'sql';
}
