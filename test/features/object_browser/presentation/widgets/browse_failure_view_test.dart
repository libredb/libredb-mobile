@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

void main() {
  late int retries;

  setUp(() => retries = 0);

  Widget app(AppError error, {required bool offline}) => MaterialApp(
    localizationsDelegates: const [S.delegate],
    home: OfflineStatus(
      isOffline: offline,
      child: Scaffold(
        body: BrowseFailureView(connectionId: 'seed:dev-postgres', error: error, onRetry: () => retries++),
      ),
    ),
  );

  final offline = NetworkError('offline', code: AppErrorCode.networkOffline.key);

  testWidgets('a failure for want of a connection loads again once, when the device is back online', (tester) async {
    await tester.pumpWidget(app(offline, offline: true));
    expect(retries, 0);

    await tester.pumpWidget(app(offline, offline: false));
    await tester.pumpWidget(app(offline, offline: false));

    expect(retries, 1);
  });

  testWidgets('a network failure without a code loads again too', (tester) async {
    await tester.pumpWidget(app(const NetworkError('socket closed'), offline: true));
    await tester.pumpWidget(app(const NetworkError('socket closed'), offline: false));

    expect(retries, 1);
  });

  testWidgets('a failure shown online sends nothing by itself', (tester) async {
    await tester.pumpWidget(app(offline, offline: false));

    expect(retries, 0);
  });

  for (final error in [
    const ServerError('down', code: 'studio.database_unreachable'),
    NetworkError('bad certificate', code: AppErrorCode.networkCertInvalid.key),
  ]) {
    testWidgets('a failure that a connection does not cure stays as it is (${error.code})', (tester) async {
      await tester.pumpWidget(app(error, offline: true));
      await tester.pumpWidget(app(error, offline: false));

      expect(retries, 0);
    });
  }
}
