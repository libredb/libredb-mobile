import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How the system bars are drawn over an app painted in [colors].
///
/// Answers the Play Console's "Edge-to-edge may not display for all users" against the 1.2.0 release.
///
/// The navigation bar is what this exists for. `MaterialApp._themeBuilder` sets `SystemUiOverlayStyle.dark` under a
/// light theme and `.light` under a dark one, and both of those constants hold the navigation bar fixed at
/// `systemNavigationBarColor: Color(0xFF000000)` with `systemNavigationBarIconBrightness: Brightness.light`
/// (`services/system_chrome.dart`): one black bar with white icons, whatever the app is painted in.
///
/// That was readable only while the black was really drawn. The app targets SDK 36, so Android 15 and up draw it
/// edge-to-edge and ignore `systemNavigationBarColor`: the bar is transparent, the app's own pixels are behind it,
/// and under the light theme those are `surface`, `0xFFFFFFFF`. White icons — and, under gesture navigation, a
/// white handle — on white. It is the Android twin of #442, where the top inset was painted black on iOS.
///
/// Both navigation-bar keys move together, because the colour still applies below Android 15, where icons alone
/// would read as dark on black. Painting the bar `surface` makes one rule hold at every version the app runs on:
/// the bar belongs to the app, so it carries the app's colour and its icons contrast with it.
///
/// The two status-bar keys repeat what `MaterialApp` already sets, value for value — a light theme asks for dark
/// icons over a light background — because `RenderView._updateSystemChrome` takes every key from this one
/// annotation when no other annotation sits at the head of the screen, and leaving them out would send null for
/// each. Nothing about the status bar changes here; it was measured correct and stays as it was.
SystemUiOverlayStyle systemBarsFor(ColorScheme colors) {
  final icons = colors.brightness == Brightness.light ? Brightness.dark : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarIconBrightness: icons,
    statusBarBrightness: colors.brightness,
    systemNavigationBarColor: colors.surface,
    systemNavigationBarIconBrightness: icons,
  );
}

/// Draws the system bars against the theme [child] is painted in, wherever the app has got to.
///
/// It sits in `MaterialApp.builder`, above the router and the gates, so the one annotation covers every page, every
/// dialog and every bottom sheet. `RenderView._updateSystemChrome` (`rendering/view.dart`) reads the annotation
/// under the centre of each bar; a page that puts its own at the head of the screen, such as an `AppBar`, keeps the
/// status bar and leaves the navigation bar to this one.
class AppSystemBars extends StatelessWidget {
  const AppSystemBars({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: systemBarsFor(Theme.of(context).colorScheme), child: child);
}
