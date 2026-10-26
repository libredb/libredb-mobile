@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/account_refusal_status.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/studio_unreachable_status.dart';

void main() {
  late int retries;

  setUp(() => retries = 0);

  Widget app(
    AppError error, {
    required bool offline,
    bool refused = false,
    bool unreachable = false,
    bool runsStatement = false,
  }) => MaterialApp(
    localizationsDelegates: const [S.delegate],
    home: OfflineStatus(
      isOffline: offline,
      child: StudioUnreachableStatus(
        isUnreachable: unreachable,
        child: AccountRefusalStatus(
          isRefused: refused,
          child: Scaffold(
            body: BrowseFailureView(
              connectionId: 'seed:dev-postgres',
              error: error,
              runsStatement: runsStatement,
              onRetry: () => retries++,
            ),
          ),
        ),
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

  testWidgets('a network failure without a code waits for Retry, since its request may have reached Studio', (
    tester,
  ) async {
    await tester.pumpWidget(app(const NetworkError('socket closed'), offline: true));
    await tester.pumpWidget(app(const NetworkError('socket closed'), offline: false));

    expect(retries, 0);
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

  // The page stayed mounted under the shell's refusal page and failed there; Studio accepting the account again loads
  // it once, as a pull to refresh would.
  final refusedAccount = AuthError('No role', code: AppErrorCode.studioAccountHasNoRole.key);

  testWidgets('a failure loads again once, when Studio accepts the account again', (tester) async {
    await tester.pumpWidget(app(refusedAccount, offline: false, refused: true));
    expect(retries, 0);

    await tester.pumpWidget(app(refusedAccount, offline: false));
    await tester.pumpWidget(app(refusedAccount, offline: false));

    expect(retries, 1);
  });

  testWidgets('a failure whose retry runs a statement waits for Retry after the account is accepted', (tester) async {
    await tester.pumpWidget(app(refusedAccount, offline: false, refused: true, runsStatement: true));
    await tester.pumpWidget(app(refusedAccount, offline: false, runsStatement: true));

    expect(retries, 0);
  });

  // The page stayed mounted under the Studio unreachable page and failed there; a check that finds Studio answering
  // again loads it once (#343), as the connection list does (#339).
  const refused = NetworkError('Connection refused');

  testWidgets('a failure loads again once, when the Studio unreachable page uncovers it', (tester) async {
    await tester.pumpWidget(app(refused, offline: false, unreachable: true));
    expect(retries, 0);

    await tester.pumpWidget(app(refused, offline: false));
    await tester.pumpWidget(app(refused, offline: false));

    expect(retries, 1);
  });

  testWidgets('a failure whose retry runs a statement waits for Retry after the Studio unreachable page', (
    tester,
  ) async {
    await tester.pumpWidget(app(refused, offline: false, unreachable: true, runsStatement: true));
    await tester.pumpWidget(app(refused, offline: false, runsStatement: true));

    expect(retries, 0);
  });
}
