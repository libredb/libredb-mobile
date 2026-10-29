import 'package:flutter/material.dart';

/// The scroll behaviour of every scrollable in the app, installed once on `MaterialApp.scrollBehavior`: a drag past
/// an end neither stretches the screen nor glows at its edge.
///
/// Both effects come from the behaviour `MaterialApp` installs by default, through two different doors, which is why
/// one override is not enough:
///
/// * the physics, where iOS and macOS answer [BouncingScrollPhysics] and the content itself follows the finger past
///   the end — [getScrollPhysics] answers [ClampingScrollPhysics] instead, the physics Android already uses and the
///   one `RefreshIndicator` is built against;
/// * the overscroll indicator, where Android wraps every scrollable in a `StretchingOverscrollIndicator` under
///   Material 3, or a `GlowingOverscrollIndicator` before it — [buildOverscrollIndicator] builds neither, and hands
///   the child straight back.
///
/// [MaterialScrollBehavior] is the base rather than [ScrollBehavior] so that everything else it decides — the
/// scrollbar, the devices that may drag a scrollable, the platform it reads off the theme — stays as `MaterialApp`
/// had it.
///
/// Known and intended: on iOS the bounce is the platform convention, and its absence is a deliberate deviation the
/// owner asked for (#418). There is no platform exception here — the behaviour is the same on both.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
