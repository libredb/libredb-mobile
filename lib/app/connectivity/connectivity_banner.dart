import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_durations.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// An animated banner that appears at the top of the scaffold when the device is offline.
///
/// Listens to [ConnectivityCubit] and fades and collapses in both directions. It leaves the way it arrives: the
/// previous version swapped the content for an empty box in the same frame the state changed, so the two implicit
/// animations wrapped around it ran on nothing and the banner vanished instead of sliding away (#367). An
/// [AnimatedSwitcher] is what keeps the departing content mounted for as long as its own animation lasts.
///
/// It also holds the status-bar inset at all times, online or not. Both shells sit it above the body in a `Column`
/// and give it that inset with `removePadding(removeTop: true)`, so an inset the banner only held while offline would
/// be handed over in the same frame as the state while the banner's own height took the whole animation to follow —
/// and the body would jump by the height of the status bar at each end.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).top;
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The inset keeps its height and only changes colour, so the body below never moves because of it.
          AnimatedContainer(
            duration: AppDurations.normal,
            curve: AppDurations.easeInOut,
            height: inset,
            color: state.isOffline ? Theme.of(context).colorScheme.error : Colors.transparent,
          ),
          _message(context, state),
        ],
      ),
    );
  }

  Widget _message(BuildContext context, ConnectivityState state) {
    return AnimatedSwitcher(
      duration: AppDurations.normal,
      switchInCurve: AppDurations.easeInOut,
      switchOutCurve: AppDurations.easeInOut,
      // The size goes with it, so the banner takes no room once it has left and claims none before it arrives.
      // The height alone reads as the slide; an actual SlideTransition on top of it would move the content up
      // inside a band that is already being clipped from the bottom, which sent the message over the status bar
      // for the length of the animation.
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: state.isOffline
          ? _OfflineBannerContent(key: const ValueKey('connectivity-offline'))
          : const SizedBox.shrink(key: ValueKey('connectivity-online')),
    );
  }
}

class _OfflineBannerContent extends StatelessWidget {
  const _OfflineBannerContent({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // A screen reader announces the change, with what it means for the data on screen, and reads the label once.
    return Semantics(
      container: true,
      liveRegion: true,
      label: S.of(context).connectivity_offline_semantics,
      child: ExcludeSemantics(child: _content(context, colorScheme)),
    );
  }

  Widget _content(BuildContext context, ColorScheme colorScheme) {
    return Material(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(color: colorScheme.error),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, color: colorScheme.onError, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              S.of(context).connectivity_offline,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: colorScheme.onError, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
