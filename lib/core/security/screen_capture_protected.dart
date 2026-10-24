import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:libredb_mobile/core/security/screen_capture_protection.dart';

/// Mixin for a [State] whose widget shows data that must not be captured: it holds a lease of the
/// [ScreenCaptureProtection] above it while the widget is on screen and releases it in [dispose].
///
/// On screen means mounted with its tickers on: an offstage subtree, such as a route covered by an opaque page or the
/// shell hidden under the refusal page, has [TickerMode] off and holds no lease, so the screen shown above it can be
/// captured; a sheet over the widget leaves its tickers on and keeps the lease.
///
/// Reads the protection when the widget is mounted, and fails there when none is provided, rather than showing the
/// data unprotected.
mixin ScreenCaptureProtected<T extends StatefulWidget> on State<T> {
  late final ScreenCaptureProtection _protection = context.read<ScreenCaptureProtection>();
  bool _holdsLease = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onScreen = TickerMode.valuesOf(context).enabled;
    if (onScreen == _holdsLease) return;
    _holdsLease = onScreen;
    if (onScreen) {
      _protection.acquire();
    } else {
      _protection.release();
    }
  }

  @override
  void dispose() {
    if (_holdsLease) _protection.release();
    super.dispose();
  }
}
