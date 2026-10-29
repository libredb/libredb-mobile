import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../tokens/app_spacing.dart';
import '../tokens/app_radius.dart';

/// Skeleton shape variants.
enum AppSkeletonShape { text, circle, rectangle, card, listTile }

/// Shimmer-based loading placeholder.
class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final AppSkeletonShape shape;
  final BorderRadius? borderRadius;

  const AppSkeleton({super.key, this.width, this.height, this.shape = AppSkeletonShape.rectangle, this.borderRadius});

  /// A text-line skeleton.
  const AppSkeleton.text({super.key, this.width = 200, this.height = 14})
    : shape = AppSkeletonShape.text,
      borderRadius = null;

  /// A circular skeleton (avatar placeholder).
  const AppSkeleton.circle({super.key, double diameter = 40})
    : width = diameter,
      height = diameter,
      shape = AppSkeletonShape.circle,
      borderRadius = null;

  /// A card-shaped skeleton.
  const AppSkeleton.card({super.key, this.width, this.height = 120})
    : shape = AppSkeletonShape.card,
      borderRadius = null;

  /// A list tile skeleton.
  factory AppSkeleton.listTile({Key? key}) {
    return AppSkeleton._listTile(key: key);
  }

  const AppSkeleton._listTile({super.key})
    : width = null,
      height = 64,
      shape = AppSkeletonShape.listTile,
      borderRadius = null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = skeletonBase(colorScheme);
    final highlightColor = skeletonHighlight(colorScheme);

    if (shape == AppSkeletonShape.listTile) {
      return _StillWhileTheRouteMoves(
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _StillWhileTheRouteMoves(
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: shape == AppSkeletonShape.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: shape == AppSkeletonShape.circle
                ? null
                : borderRadius ?? BorderRadius.circular(shape == AppSkeletonShape.card ? AppRadius.md : 4),
          ),
        ),
      ),
    );
  }
}

/// Holds [child]'s animations still while the page it is on is arriving or being covered by the next one.
///
/// The sweep never stops on its own — it is an `AnimationController.repeat()` — and Flutter mutes a route's tickers
/// only once the route above it has finished arriving. For the length of every transition out of a page that is
/// still loading, the placeholder therefore sweeps on a page on its way off the screen: motion where the transition
/// wants stillness, and the same class of defect as the animation #367 left running on a child nobody could see
/// (#421, measured at 44,168 changed pixels over one 360 ms route change).
///
/// `TickerMode` combines with the ancestor mode rather than overriding it, so this only ever adds stillness, and the
/// `shimmer` package drives its controller from a `SingleTickerProviderStateMixin`, which is what obeys it.
///
/// The route is the nearest one, which for a page inside a shell is its own page rather than the shell's. A skeleton
/// with no route above it at all — one built directly in a test — is left alone.
class _StillWhileTheRouteMoves extends StatefulWidget {
  const _StillWhileTheRouteMoves({required this.child});

  final Widget child;

  @override
  State<_StillWhileTheRouteMoves> createState() => _StillWhileTheRouteMovesState();
}

class _StillWhileTheRouteMovesState extends State<_StillWhileTheRouteMoves> {
  ModalRoute<dynamic>? _route;
  bool _moving = false;

  /// Whether the page is on its way in, or on its way under the page above it.
  ///
  /// A route with no animations of its own is not moving: the answer has to default to letting the sweep run, or a
  /// placeholder would sit frozen on a page that is simply open.
  bool get _routeIsMoving {
    final arriving = _route?.animation;
    final covered = _route?.secondaryAnimation;
    if (arriving == null || covered == null) return false;
    return arriving.status != AnimationStatus.completed || covered.status != AnimationStatus.dismissed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `ModalRoute.of` is an inherited lookup, so this runs again when the page is handed a different route; the
    // animations themselves live as long as the route does.
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _stopListening();
    _route = route;
    // The status, not only the value: a route's controller reports `forward` the moment the next page is pushed,
    // a frame before its first tick. Waiting for the value would let the sweep through one more frame — measured,
    // 1,274 changed pixels of exactly the motion this is here to stop.
    _route?.animation?.addStatusListener(_syncWithTheRouteStatus);
    _route?.secondaryAnimation?.addStatusListener(_syncWithTheRouteStatus);
    _moving = _routeIsMoving;
  }

  void _stopListening() {
    _route?.animation?.removeStatusListener(_syncWithTheRouteStatus);
    _route?.secondaryAnimation?.removeStatusListener(_syncWithTheRouteStatus);
  }

  void _syncWithTheRouteStatus(AnimationStatus status) => _syncWithTheRoute();

  /// Rebuilds only when the answer changes, rather than on every tick of a transition.
  void _syncWithTheRoute() {
    final moving = _routeIsMoving;
    if (moving != _moving) setState(() => _moving = moving);
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(enabled: !_moving, child: widget.child);
}

/// What the placeholder is filled with.
Color skeletonBase(ColorScheme scheme) => scheme.surfaceContainerHighest;

/// The light that sweeps over [skeletonBase].
///
/// Lifted off the base rather than taken from a token, because no single token is lighter than the base in both
/// brightnesses: this used to be `surface`, which is lighter than the base in a light scheme and the darkest colour
/// there is in a dark one, so in dark mode the sweep was a shadow rather than a shimmer (#373).
Color skeletonHighlight(ColorScheme scheme) => Color.lerp(skeletonBase(scheme), Colors.white, 0.35)!;
