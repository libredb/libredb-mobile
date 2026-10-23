import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

/// A Browse page's pull to refresh: [refresh] online, which completes once the answer or its failure is on screen;
/// offline it sends nothing and says the device is offline, as the connection banner does.
Future<void> refreshBrowseUnlessOffline(BuildContext context, Future<void> Function() refresh) async {
  if (OfflineStatus.isOfflineOf(context)) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.of(context).connectivity_offline)));
    return;
  }
  await refresh();
}

/// The scroll behaviour above a result view, so that a result shorter than the page still pulls to refresh: every
/// scrollable below it is always scrollable, on top of the platform's physics, which stop it at its ends. Bare
/// [AlwaysScrollableScrollPhysics] would replace them, and a drag past an end would stay there.
ScrollBehavior alwaysScrollableBrowseBehavior(BuildContext context) {
  final behavior = ScrollConfiguration.of(context);
  return behavior.copyWith(physics: const AlwaysScrollableScrollPhysics().applyTo(behavior.getScrollPhysics(context)));
}

/// Which scrolls pull a result view to refresh: a vertical one at depth 0, the card list, or at depth 1, the table's
/// rows inside its sideways scroll. The default predicate takes depth 0 only, so a pull on the table refreshed nothing.
bool browseResultRefreshPredicate(ScrollNotification notification) =>
    notification.metrics.axis == Axis.vertical && notification.depth <= 1;
