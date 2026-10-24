import 'package:flutter/widgets.dart';

import 'package:libredb_mobile/core/security/screen_capture_protected.dart';

/// Keeps [child] out of screenshots, screen recordings and the recent-apps preview while it is on screen, by holding a
/// lease of the app's `ScreenCaptureProtection` ([ScreenCaptureProtected]); a stateless widget wraps its value area in
/// it without becoming stateful.
///
/// Wrap the area that shows the values, not the whole page, so the rest of the app stays capturable.
class ScreenCaptureGuard extends StatefulWidget {
  const ScreenCaptureGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ScreenCaptureGuard> createState() => _ScreenCaptureGuardState();
}

class _ScreenCaptureGuardState extends State<ScreenCaptureGuard> with ScreenCaptureProtected<ScreenCaptureGuard> {
  @override
  Widget build(BuildContext context) => widget.child;
}
