import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/onboarding/presentation/widgets/key_mark.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The fourth screen of the introduction: where the database password was.
///
/// Three boxes on one wire — this app, LibreDB Studio, `orders-prod` — and the whole screen is one claim drawn rather
/// than written. Current fills the upper wire, a comet runs down it beside the token carrying `seed:7`, which **stays
/// at Studio**; the key on Studio shuts; the lower wire carries a pulse to the database; and rows travel back up.
/// Nothing ever travels the whole way from this app to the database, which is the same thing the closing note says
/// in words.
///
/// **It draws its hero and nothing else** — the caption, the headline, the body, the counter, the progress and the
/// controls are the chassis's — and nothing here is tappable.
///
/// **The token cannot reach the database.** It is aligned inside the upper wire's own box, between the app and Studio,
/// so there is no frame at which it could be drawn further down; `step_4_credentials_test.dart` measures that rather
/// than trusting it.
///
/// **What the screen claims, against `docs/security.md`.** The app holds no database credential at all: Studio opens
/// every connection and this app names one as `{'connectionId': 'seed:<id>'}`. What it does hold is the provider's
/// tokens, in `flutter_secure_storage` — AES-GCM under an Android Keystore key, or the Keychain at
/// `first_unlock_this_device` — and they expire, with a 15-minute idle sign-out in prod on top. The app lock
/// (`docs/security.md`, 'App lock') stands between a stranger and a client that can run statements. It gates the app
/// rather than encrypting the store, so 'that session sits behind the lock' is the narrow claim the headline keeps,
/// not a claim about the token's own encryption.
class Step4Credentials extends StatefulWidget {
  const Step4Credentials({super.key});

  /// The database at the foot of the chain, and the engine under it.
  static const connectionName = 'orders-prod';
  static const engine = 'postgres';

  /// What the app sends: the name of a connection, never a credential. The whole of what travels the upper wire.
  static const connectionReference = 'seed:7';

  // The beats, as `PLAY[3]` of the prototype times them, measured from the frame the screen is shown.

  /// The three boxes arrive, one after another, each over [AppDurations.media].
  static const nodesArriveEvery = Duration(milliseconds: 90);

  /// The upper wire lights and the `seed:7` token sets off down it.
  static const requestAt = Duration(milliseconds: 450);

  /// How long a token or a pulse takes to travel one wire.
  static const travelTakes = Duration(milliseconds: 640);

  /// The padlock on Studio shuts. The password stops here because it never left here.
  static const keyShutsAt = Duration(milliseconds: 1100);

  /// The lower wire lights and a pulse sets off for the database.
  static const connectsAt = Duration(milliseconds: 1550);

  /// The database answers.
  static const databaseAt = Duration(milliseconds: 2200);

  /// The rows start back up the lower wire, then the upper one.
  static const rowsUpLowerAt = Duration(milliseconds: 2600);
  static const rowsUpUpperAt = Duration(milliseconds: 3100);

  /// The rows are here, and the closing note says what came back and what did not.
  static const rowsReturnAt = Duration(milliseconds: 3700);

  /// The whole timeline, long enough for the closing note's own fade and the last ring (700 ms from the rows
  /// returning) to finish inside it.
  static const plays = Duration(milliseconds: 4400);

  /// The wire between this app and Studio — the only stretch the request token is ever drawn on.
  static const upperWireKey = ValueKey('ob_step4_upper_wire');

  /// The travelling token that carries [connectionReference].
  static const requestTokenKey = ValueKey('ob_step4_request_token');

  /// The closing note, whose fade a test reads rather than looking at the drawing.
  static const closingNoteKey = ValueKey('ob_step4_closing_note');

  @override
  State<Step4Credentials> createState() => _Step4CredentialsState();
}

class _Step4CredentialsState extends State<Step4Credentials> with SingleTickerProviderStateMixin {
  /// The prototype's own measures of this hero, from headless Chrome at 390x844 (`ob.html`, screen 4). None is on the
  /// closed spacing scale and all are this screen's own: `.node{padding:10px 12px;gap:9px;border-radius:12px}`,
  /// `.wire{height:42px;margin-left:26px}`, `.tok{left:10px;top:12px;padding:2px 7px}`, `.comet{width:8px;
  /// left:-3.5px}`, `.key{width:16px}` and `.note{margin-top:8px}`.
  static const _nodePadX = 12.0;
  static const _nodePadY = 10.0;
  static const _nodeGap = 9.0;
  static const _wireHeight = 42.0;
  static const _wireIndent = 26.0;
  static const _tokenLeft = 10.0;
  static const _tokenTop = 12.0;
  static const _tokenPadX = 7.0;
  static const _tokenPadY = 2.0;
  static const _cometSize = 8.0;
  static const _cometLeft = -3.5;
  static const _cometGlow = 12.0;
  static const _keySize = 16.0;
  static const _keyShutScale = 1.15;

  /// The type: `.node .t{font-size:12.5px;font-weight:600}` over a 16 line, `.node .m` and the note in mono 11 over a
  /// 14 line and a 1.5 one, the title's gap to its line `margin-top:2px`.
  static const _titleSize = 12.5;
  static const _titleLine = 16 / _titleSize;
  static const _small = 11.0;
  static const _monoLine = 14 / _small;
  static const _noteLine = 1.5;
  static const _lineGap = 2.0;

  /// A wire's rail and the current filling it: `.wire:before{width:1px}`, `.energy{width:1.5px}`.
  static const _rail = 1.0;
  static const _current = 1.5;

  /// A node's ring and pop: `.ring{border:1.5px;opacity:.85}` growing to 1.13 over `.7s`, `.pop` to 1.05 over `.4s`.
  static const _ringWidth = 1.5;
  static const _ringOpacity = 0.85;
  static const _ringGrowth = 0.13;
  static const _ringFor = Duration(milliseconds: 700);
  static const _popScale = 1.05;
  static const _popFor = Duration(milliseconds: 400);

  /// How far a box comes in from below as it arrives: `@keyframes rise{from{transform:translateY(13px)}}`.
  static const _arrivesFrom = 13.0;

  /// The arrow the note leads with, a character of its text and not an icon.
  static const _arrow = '↑';

  /// The field name the app sends a connection under, as `docs/architecture.md` spells it. An identifier, the same in
  /// every language.
  static const _connectionIdKey = 'connectionId';

  late final AnimationController _play = AnimationController(vsync: this, duration: Step4Credentials.plays);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With animations off the screen is its finished state from the first frame: the key shut, both wires live,
    // the token resting at Studio and the closing note up.
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

  Duration get _elapsed => Step4Credentials.plays * _play.value;

  /// How far into [beat]'s own animation of length [over] the timeline is, eased by the design system's entrance.
  double _eased(Duration at, Duration beat, Duration over) {
    final into = at - beat;
    if (into <= Duration.zero) return 0;
    final fraction = (into.inMicroseconds / over.inMicroseconds).clamp(0.0, 1.0);
    return AppDurations.easeOut.transform(fraction);
  }

  /// The same, without the easing: where a beat has got to, 0 to 1.
  double _linear(Duration at, Duration beat, Duration over) {
    final into = at - beat;
    if (into <= Duration.zero) return 0;
    return (into.inMicroseconds / over.inMicroseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mono = theme.textTheme.labelSmall?.copyWith(
      fontFamily: AppTypography.mono,
      fontSize: _small,
      height: _monoLine,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
    );

    return AnimatedBuilder(
      animation: _play,
      builder: (context, _) {
        final at = _elapsed;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _node(
              0,
              at,
              theme,
              mono,
              arrivesAt: Duration.zero,
              popsAt: Step4Credentials.rowsReturnAt,
              title: s.ob4_app,
              detail: Text(
                '$_connectionIdKey: "${Step4Credentials.connectionReference}"',
                style: mono?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            _wire(
              at,
              colors,
              mono,
              key: Step4Credentials.upperWireKey,
              cometKey: const ValueKey('ob4-comet-upper'),
              liveAt: Step4Credentials.requestAt,
              label: Step4Credentials.connectionReference,
              tokenKey: Step4Credentials.requestTokenKey,
              down: Step4Credentials.requestAt,
              up: Step4Credentials.rowsUpUpperAt,
            ),
            _node(
              1,
              at,
              theme,
              mono,
              arrivesAt: Step4Credentials.nodesArriveEvery,
              popsAt: Step4Credentials.keyShutsAt,
              title: s.ob4_studio,
              lit: at >= Step4Credentials.keyShutsAt,
              keyAt: Step4Credentials.keyShutsAt,
              detail: Text(
                s.ob4_vault,
                style: mono?.copyWith(color: colors.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
            _wire(
              at,
              colors,
              mono,
              cometKey: const ValueKey('ob4-comet-lower'),
              liveAt: Step4Credentials.connectsAt,
              label: s.ob4_connects,
              down: Step4Credentials.connectsAt,
              up: Step4Credentials.rowsUpLowerAt,
            ),
            _node(
              2,
              at,
              theme,
              mono,
              arrivesAt: Step4Credentials.nodesArriveEvery * 2,
              popsAt: Step4Credentials.databaseAt,
              title: Step4Credentials.connectionName,
              detail: Text(Step4Credentials.engine, style: mono?.copyWith(color: colors.onSurfaceVariant)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Opacity(
              key: Step4Credentials.closingNoteKey,
              opacity: _eased(at, Step4Credentials.rowsReturnAt, AppDurations.media),
              child: Text(
                '$_arrow ${s.ob4_back}',
                style: mono?.copyWith(color: colors.onPrimaryContainer, height: _noteLine),
              ),
            ),
          ],
        );
      },
    );
  }

  /// One box of the chain: what it is, what it holds, and — on Studio — the key that shuts on it.
  ///
  /// It arrives like every box of the screen, pops once at [popsAt] with a ring running out of it, and is lit only
  /// where [lit]: of the three, `.node.lit` is Studio's alone.
  Widget _node(
    int index,
    Duration at,
    ThemeData theme,
    TextStyle? mono, {
    required Duration arrivesAt,
    required Duration popsAt,
    required String title,
    required Widget detail,
    bool lit = false,
    Duration? keyAt,
  }) {
    final colors = theme.colorScheme;
    final arrived = _eased(at, arrivesAt, AppDurations.media);
    final pop = _linear(at, popsAt, _popFor);
    final ring = _linear(at, popsAt, _ringFor);
    final shut = keyAt == null ? 0.0 : _eased(at, keyAt, AppDurations.slow);
    final node = Container(
      key: ValueKey('ob4-node-$index'),
      decoration: BoxDecoration(
        color: lit ? colors.primaryContainer : colors.surface,
        border: Border.all(color: lit ? colors.primary : colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      foregroundDecoration: ring > 0 && ring < 1 ? _RingDecoration(colors.primary, ring) : null,
      padding: const EdgeInsets.symmetric(horizontal: _nodePadX, vertical: _nodePadY),
      child: Row(
        spacing: _nodeGap,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: _titleSize,
                    height: _titleLine,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                    color: lit ? colors.onPrimaryContainer : colors.onSurface,
                  ),
                ),
                const SizedBox(height: _lineGap),
                detail,
              ],
            ),
          ),
          if (keyAt != null)
            // `.key{color:var(--edge)}` going to the accent as it shuts, and `.shut{transform:scale(1.15)}`.
            Transform.scale(
              scale: 1 + (_keyShutScale - 1) * shut,
              child: KeyMark(
                key: const ValueKey('ob4-key'),
                size: _keySize,
                color: Color.lerp(colors.outline, colors.primary, shut)!,
              ),
            ),
        ],
      ),
    );
    return Opacity(
      opacity: arrived,
      child: Transform.translate(
        offset: Offset(0, _arrivesFrom * (1 - arrived)),
        child: Transform.scale(
          key: ValueKey('ob4-pop-$index'),
          scale: 1 + (_popScale - 1) * _popCurve(pop),
          child: node,
        ),
      ),
    );
  }

  /// `.pop`: up to the full scale by 38% of the beat and back to rest by its end.
  double _popCurve(double t) {
    if (t <= 0 || t >= 1) return 0;
    return t < 0.38 ? AppDurations.easeOut.transform(t / 0.38) : 1 - AppDurations.easeOut.transform((t - 0.38) / 0.62);
  }

  /// One stretch of wire: the rail, the current filling it from the top, the label that comes with the current, and
  /// the comets that run down it and back up.
  ///
  /// The label is the pill the prototype pins at `left:10px;top:12px` of the wire's own box, so for every value of the
  /// timeline it is drawn between the two boxes this wire joins and can reach neither.
  Widget _wire(
    Duration at,
    ColorScheme colors,
    TextStyle? mono, {
    required Key cometKey,
    required Duration liveAt,
    required String label,
    required Duration down,
    required Duration up,
    Key? key,
    Key? tokenKey,
  }) {
    final live = _eased(at, liveAt, AppDurations.media);
    final shown = _eased(at, liveAt, AppDurations.normal);
    final comet =
        _comet(at, colors, key: cometKey, start: down, goesDown: true) ??
        _comet(at, colors, key: cometKey, start: up, goesDown: false);
    return Padding(
      padding: const EdgeInsets.only(left: _wireIndent),
      child: SizedBox(
        key: key,
        height: _wireHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _rail,
              child: ColoredBox(color: colors.outline),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: _current,
              height: _wireHeight * live,
              child: ColoredBox(color: colors.primary),
            ),
            ?comet,
            // The `Align` bounds the pill to the wire's own width, so a label at an accessibility text size folds
            // inside the hero instead of running out of it.
            Positioned(
              left: _tokenLeft,
              top: _tokenTop,
              right: 0,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Opacity(
                  opacity: shown,
                  child: Container(
                    key: tokenKey,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: _tokenPadX, vertical: _tokenPadY),
                    child: Text(label, style: mono?.copyWith(color: colors.onPrimary)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The comet that runs [goesDown] the wire or back up it from [start], or null when none is running: `@keyframes
  /// cd`/`cu`, 8 across with a glow, in at 12% of the beat and gone by its end.
  Widget? _comet(Duration at, ColorScheme colors, {required Key key, required Duration start, required bool goesDown}) {
    final t = _linear(at, start, Step4Credentials.travelTakes);
    if (t <= 0 || t >= 1) return null;
    final travelled = AppDurations.easeOut.transform(t);
    final opacity = t < 0.12 ? t / 0.12 : 1 - (t - 0.12) / 0.88;
    final scale = t < 0.12 ? 0.4 + 0.6 * (t / 0.12) : 1.0;
    return Positioned(
      left: _cometLeft,
      top: _wireHeight * (goesDown ? travelled : 1 - travelled),
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            key: key,
            width: _cometSize,
            height: _cometSize,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: colors.primary, blurRadius: _cometGlow)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring that runs out of a box: `.ring{border:1.5px solid var(--accent)}` over the box's padding edge, fading from
/// .85 as it grows to 1.13 of itself. It is painted, not laid out, so it draws past the box without being one.
class _RingDecoration extends Decoration {
  const _RingDecoration(this.color, this.progress);

  final Color color;
  final double progress;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _RingPainter(color, progress);
}

class _RingPainter extends BoxPainter {
  _RingPainter(this.color, this.progress);

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final grown = 1 + _Step4CredentialsState._ringGrowth * AppDurations.easeOut.transform(progress);
    final rect = (offset & size).deflate(1);
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..scale(grown)
      ..translate(-rect.center.dx, -rect.center.dy)
      ..drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(11)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _Step4CredentialsState._ringWidth
          ..color = color.withValues(alpha: _Step4CredentialsState._ringOpacity * (1 - progress)),
      )
      ..restore();
  }
}
