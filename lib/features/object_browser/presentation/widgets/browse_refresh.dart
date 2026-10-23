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
