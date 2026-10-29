@Tags(['widget'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../support/access_request_fixtures.dart';
import '../support/access_requests_harness.dart';

void main() {
  late MockIAccessRequestRepository repository;

  setUp(() {
    repository = MockIAccessRequestRepository();
    when(repository.mine).thenAnswer((_) async => Success([fixtureRequest('r1')]));
    when(repository.requestableConnections).thenAnswer((_) async => Success([fixtureConnection('c1')]));
  });

  for (final location in [ApplicationRoutesConstants.accessRequests, ApplicationRoutesConstants.accessRequestNew]) {
    testWidgets('$location redirects to the connection list when the predicate fails, and asks Platform nothing', (
      tester,
    ) async {
      final router = await pumpAccessRequests(tester, repository, location: null, available: false);

      router.go(location);
      await tester.pumpAndSettle();

      expect(find.text('connection list'), findsOneWidget);
      expect(router.state.uri.path, ApplicationRoutesConstants.connectionList);
      verifyNever(repository.mine);
      verifyNever(repository.requestableConnections);
    });
  }

  testWidgets('both routes open their page when the predicate holds', (tester) async {
    final router = await pumpAccessRequests(tester, repository, location: null);

    router.go(ApplicationRoutesConstants.accessRequests);
    await tester.pumpAndSettle();
    expect(find.text('Analytics warehouse'), findsOneWidget);

    router.go(ApplicationRoutesConstants.accessRequestNew);
    await tester.pumpAndSettle();
    expect(find.text('Connection c1'), findsOneWidget);
  });
}
