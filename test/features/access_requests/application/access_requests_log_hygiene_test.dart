import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/application/access_request_form_bloc.dart';
import 'package:libredb_mobile/features/access_requests/application/my_access_requests_bloc.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/create_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_my_access_requests_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_requestable_connections_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/withdraw_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/withdraw_access_request_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../../../support/printed_lines.dart';
import '../support/access_request_fixtures.dart';

/// The three BLoCs print no reason, no administrator reason and no connection name. The texts of their events and
/// states are checked too, since the bloc observer and the dev console print them.
void main() {
  const reason = 'My secret quarterly reason';
  const decision = 'Private administrator words';
  const name = 'Confidential Ledger DB';

  test(
    'a form that loads, fails and sends, and a list that loads and withdraws, print none of the three texts',
    () async {
      final repository = MockIAccessRequestRepository();
      final connection = fixtureConnection('c1', name: name);
      final refused = fixtureRequest('r2', status: 'refused', connectionName: name, decisionReason: decision);
      when(repository.requestableConnections).thenAnswer((_) async => Success([connection]));
      when(repository.mine).thenAnswer((_) async => Success([fixtureRequest('r1', connectionName: name), refused]));
      when(() => repository.withdraw('r1')).thenAnswer(
        (_) async =>
            Failure(ValidationError('$name: $reason $decision', code: AppErrorCode.platformAccessRequestDecided.key)),
      );
      var sent = 0;
      when(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer(
        (_) async => sent++ == 0
            ? Failure(ValidationError('$name: $reason', code: AppErrorCode.platformAccessRequestReasonRefused.key))
            : Success(fixtureRequest('r9', connectionName: name)),
      );

      final texts = <String>[const AccessRequestFormReasonChanged(reason).toString()];
      final lines = await printedLines(() async {
        final form = AccessRequestFormBloc(
          listRequestableConnectionsUseCase: ListRequestableConnectionsUseCase(repository),
          createAccessRequestUseCase: CreateAccessRequestUseCase(repository),
        );
        form.stream.listen((state) => texts.add('$state'));
        form.add(const AccessRequestFormLoadRequested());
        await form.stream.firstWhere((state) => state is AccessRequestFormReady);
        form
          ..add(const AccessRequestFormConnectionPicked('c1'))
          ..add(const AccessRequestFormLevelPicked('read'))
          ..add(const AccessRequestFormReasonChanged(reason))
          ..add(const AccessRequestFormSendRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        form.add(const AccessRequestFormSendRequested());
        await form.stream.firstWhere((state) => state is AccessRequestFormSubmitted);
        await form.close();

        final list = MyAccessRequestsBloc(listMyAccessRequestsUseCase: ListMyAccessRequestsUseCase(repository));
        list.stream.listen((state) => texts.add('$state'));
        list.add(const MyAccessRequestsLoadRequested());
        await list.stream.firstWhere((state) => state is MyAccessRequestsLoaded);
        final withdraw = WithdrawAccessRequestBloc(
          withdrawAccessRequestUseCase: WithdrawAccessRequestUseCase(repository),
        );
        withdraw.stream.listen((state) => texts.add('$state'));
        withdraw.add(const WithdrawAccessRequestRequested('r1'));
        await withdraw.stream.firstWhere((state) => state is WithdrawAccessRequestFailed);
        list.add(MyAccessRequestReplaced(refused));
        await Future<void>.delayed(Duration.zero);
        await list.close();
        await withdraw.close();
      });

      for (final secret in [reason, decision, name]) {
        expect(lines.where((line) => line.contains(secret)), isEmpty, reason: 'a log line carries "$secret"');
        expect(
          texts.where((text) => text.contains(secret)),
          isEmpty,
          reason: 'a state or event text carries "$secret"',
        );
      }
      expect(lines, isNotEmpty);
    },
  );
}
