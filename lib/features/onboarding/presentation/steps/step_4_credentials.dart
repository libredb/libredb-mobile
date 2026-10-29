import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_typography.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// The fourth screen of the introduction: where the database password was.
///
/// Three boxes on one wire — this app, LibreDB Studio, `orders-prod` — and the whole screen is one claim drawn rather
/// than written. Current fills the upper wire, a token carrying `seed:7` travels down it and **stops at Studio**; the
/// padlock on Studio shuts; the lower wire carries a pulse to the database; and rows travel back up. Nothing ever
/// travels the whole way from this app to the database, which is the same thing the closing note says in words.
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

  /// The whole timeline, long enough for the closing note's own fade to finish inside it.
  static const plays = Duration(milliseconds: 4300);

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
  /// A wire's length. The one measure the travel is scaled against.
  static const _wireLength = AppSpacing.xxxxl;

  /// A rule's thickness. The spacing scale has no hairline; this is what `Border.all` draws by default, lifted just
  /// enough that a lit wire reads as current rather than as an edge.
  static const _rail = 1.5;

  /// Where across a wire's box the travelling token sits: clear of the rail, and far enough from the trailing edge
  /// that a long token still has room.
  static const _tokenLane = -0.45;

  /// How far a box comes in from below as it arrives.
  static const _arrivesFrom = AppSpacing.md;

  /// The field name the app sends a connection under, as `docs/architecture.md` spells it. An identifier, the same in
  /// every language.
  static const _connectionIdKey = 'connectionId';

  late final AnimationController _play = AnimationController(vsync: this, duration: Step4Credentials.plays);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With animations off the screen is its finished state from the first frame: the padlock shut, both wires live,
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
            _arriving(
              at,
              Duration.zero,
              _node(
                theme,
                colors,
                mono,
                title: s.ob4_app,
                detail: '$_connectionIdKey: "${Step4Credentials.connectionReference}"',
                lit: at >= Step4Credentials.rowsReturnAt,
              ),
            ),
            _wire(
              at,
              colors,
              key: Step4Credentials.upperWireKey,
              liveAt: Step4Credentials.requestAt,
              token: _token(
                at,
                colors,
                mono,
                key: Step4Credentials.requestTokenKey,
                label: Step4Credentials.connectionReference,
                from: Step4Credentials.requestAt,
                // Once it has arrived it stays where it arrived, at the foot of this wire. The request got as far as
                // Studio and no further, and the drawing keeps saying so.
                rests: true,
              ),
              returning: _pulse(at, colors, from: Step4Credentials.rowsUpUpperAt),
            ),
            _arriving(
              at,
              Step4Credentials.nodesArriveEvery,
              _node(
                theme,
                colors,
                mono,
                title: s.ob4_studio,
                detail: s.ob4_vault,
                lit: at >= Step4Credentials.keyShutsAt,
                padlock: at >= Step4Credentials.keyShutsAt,
              ),
            ),
            _wire(
              at,
              colors,
              liveAt: Step4Credentials.connectsAt,
              token: _token(at, colors, mono, label: s.ob4_connects, from: Step4Credentials.connectsAt, rests: true),
              returning: _pulse(at, colors, from: Step4Credentials.rowsUpLowerAt),
            ),
            _arriving(
              at,
              Step4Credentials.nodesArriveEvery * 2,
              _node(
                theme,
                colors,
                mono,
                title: Step4Credentials.connectionName,
                detail: Step4Credentials.engine,
                lit: at >= Step4Credentials.databaseAt,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Opacity(
              key: Step4Credentials.closingNoteKey,
              opacity: _eased(at, Step4Credentials.rowsReturnAt, AppDurations.media),
              child: Row(
                children: [
                  Icon(Icons.north, size: AppSizes.iconSm, color: colors.onPrimaryContainer),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(s.ob4_back, style: mono.copyWith(color: colors.onPrimaryContainer)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Fades [child] in and lifts it the last few points into place.
  Widget _arriving(Duration at, Duration beat, Widget child) {
    final progress = _eased(at, beat, AppDurations.media);
    return Opacity(
      opacity: progress,
      child: Transform.translate(offset: Offset(0, _arrivesFrom * (1 - progress)), child: child),
    );
  }

  /// One box of the chain: what it is, what it holds, and — on Studio — the padlock that shuts on it.
  Widget _node(
    ThemeData theme,
    ColorScheme colors,
    TextStyle mono, {
    required String title,
    required String detail,
    required bool lit,
    bool? padlock,
  }) {
    final glow = lit ? 1.0 : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(colors.surface, colors.primaryContainer, glow),
        border: Border.all(color: Color.lerp(colors.outlineVariant, colors.primary, glow)!),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: lit ? colors.onPrimaryContainer : colors.onSurface,
                    ),
                  ),
                  Text(detail, style: mono.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            if (padlock != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                // Open until its own beat, shut after it. The swap is the frame, not a fade through it.
                padlock ? Icons.lock_outline : Icons.lock_open_outlined,
                size: AppSizes.iconLg,
                color: padlock ? colors.onPrimaryContainer : colors.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One stretch of wire: the rail, the current filling it from the top, and whatever is travelling on it.
  Widget _wire(
    Duration at,
    ColorScheme colors, {
    required Duration liveAt,
    required Widget token,
    required Widget returning,
    Key? key,
  }) {
    final current = _eased(at, liveAt, AppDurations.slow);
    return SizedBox(
      key: key,
      height: _wireLength,
      child: Stack(
        children: [
          Positioned(
            left: AppSpacing.xl,
            top: 0,
            bottom: 0,
            width: _rail,
            child: ColoredBox(color: colors.outlineVariant),
          ),
          Positioned(
            left: AppSpacing.xl,
            top: 0,
            width: _rail,
            height: _wireLength * current,
            child: ColoredBox(color: colors.primary),
          ),
          Positioned.fill(child: token),
          Positioned.fill(child: returning),
        ],
      ),
    );
  }

  /// A labelled token travelling down a wire from [from], and resting at the foot of it afterwards when [rests].
  ///
  /// It is placed by [Align] inside the wire's own box, so for every value of the timeline it is drawn between the two
  /// boxes this wire joins and can reach neither.
  Widget _token(
    Duration at,
    ColorScheme colors,
    TextStyle mono, {
    required String label,
    required Duration from,
    required bool rests,
    Key? key,
  }) {
    if (at < from) return const SizedBox.shrink();
    final travelled = _eased(at, from, Step4Credentials.travelTakes);
    if (travelled >= 1 && !rests) return const SizedBox.shrink();
    return Align(
      alignment: Alignment(_tokenLane, -1 + 2 * travelled),
      child: DecoratedBox(
        key: key,
        decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Text(label, style: mono.copyWith(color: colors.onPrimary)),
        ),
      ),
    );
  }

  /// A pulse travelling back up a wire from [from]: the rows returning.
  Widget _pulse(Duration at, ColorScheme colors, {required Duration from}) {
    if (at < from) return const SizedBox.shrink();
    final travelled = _eased(at, from, Step4Credentials.travelTakes);
    if (travelled >= 1) return const SizedBox.shrink();
    return Align(
      alignment: Alignment(0, 1 - 2 * travelled),
      child: Container(
        width: AppSpacing.sm,
        height: AppSpacing.sm,
        decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      ),
    );
  }
}
