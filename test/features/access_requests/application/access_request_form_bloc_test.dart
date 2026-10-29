import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/application/access_request_form_bloc.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/create_access_request_usecase.dart';
import 'package:libredb_mobile/features/access_requests/application/usecases/list_requestable_connections_usecase.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../support/access_request_fixtures.dart';

void main() {
  late MockIAccessRequestRepository repository;

  final open = fixtureConnection('c1');
  final readOnly = fixtureConnection('c2', write: false);
  final heldRead = fixtureConnection('c3', heldLevel: 'read');
  final heldWrite = fixtureConnection('c4', heldLevel: 'write');
  final pending = fixtureConnection('c5', pendingRequestId: 'r5');
  final connections = [open, readOnly, heldRead, heldWrite, pending];
  final created = fixtureRequest('r9');

  setUp(() => repository = MockIAccessRequestRepository());

  AccessRequestFormBloc build() => AccessRequestFormBloc(
    listRequestableConnectionsUseCase: ListRequestableConnectionsUseCase(repository),
    createAccessRequestUseCase: CreateAccessRequestUseCase(repository),
  );

  void answerConnections(Result<List<RequestableConnection>> result) =>
      when(repository.requestableConnections).thenAnswer((_) async => result);

  void answerCreate(Result<MyAccessRequest> result) => when(
    () => repository.create(
      connectionId: any(named: 'connectionId'),
      level: any(named: 'level'),
      reason: any(named: 'reason'),
    ),
  ).thenAnswer((_) async => result);

  Future<AccessRequestFormBloc> ready() async {
    answerConnections(Success(connections));
    final bloc = build()..add(const AccessRequestFormLoadRequested());
    await bloc.stream.firstWhere((state) => state is AccessRequestFormReady);
    return bloc;
  }

  AccessRequestFormReady readyState(AccessRequestFormBloc bloc) => bloc.state as AccessRequestFormReady;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts in Loading', () {
    expect(build().state, const AccessRequestFormLoading());
  });

  test('a load emits Ready with the requestable connections and an empty draft', () async {
    answerConnections(Success(connections));
    final bloc = build();

    bloc.add(const AccessRequestFormLoadRequested());

    expect(
      await bloc.stream.firstWhere((state) => state is! AccessRequestFormLoading),
      AccessRequestFormReady(connections: connections),
    );
    await bloc.close();
  });

  test('a failed load emits LoadFailure with the code, and a load again retries', () async {
    answerConnections(Failure(NetworkError('down', code: AppErrorCode.networkOffline.key)));
    final bloc = build()..add(const AccessRequestFormLoadRequested());
    expect(
      await bloc.stream.firstWhere((state) => state is AccessRequestFormLoadFailure),
      const AccessRequestFormLoadFailure(errorCode: AppErrorCode.networkOffline),
    );

    answerConnections(Success(connections));
    bloc.add(const AccessRequestFormLoadRequested());

    expect(
      await bloc.stream.firstWhere((state) => state is AccessRequestFormReady),
      AccessRequestFormReady(connections: connections),
    );
    await bloc.close();
  });

  group('what may be asked for', () {
    test('a free connection can be asked at either level', () {
      expect(open.canAskFor('read'), isTrue);
      expect(open.canAskFor('write'), isTrue);
      expect(open.blockedBy, isNull);
    });

    test('write cannot be asked without a write credential', () {
      expect(readOnly.canAskFor('read'), isTrue);
      expect(readOnly.canAskFor('write'), isFalse);
    });

    test('held read blocks read and leaves write; held write blocks both', () {
      expect(heldRead.canAskFor('read'), isFalse);
      expect(heldRead.canAskFor('write'), isTrue);
      expect(heldRead.blockedBy, isNull);
      expect(heldWrite.canAskFor('read'), isFalse);
      expect(heldWrite.canAskFor('write'), isFalse);
      expect(heldWrite.blockedBy, ConnectionBlock.alreadyGranted);
    });

    test('a level the app does not know counts as everything held', () {
      final admin = fixtureConnection('c6', heldLevel: 'admin');

      expect(admin.blockedBy, ConnectionBlock.alreadyGranted);
    });

    test('a pending request blocks the whole connection', () {
      expect(pending.canAskFor('read'), isFalse);
      expect(pending.canAskFor('write'), isFalse);
      expect(pending.blockedBy, ConnectionBlock.pending);
    });
  });

  group('the draft', () {
    test('picking a connection, a level and a reason keeps all three in Ready', () async {
      final bloc = await ready();

      bloc
        ..add(const AccessRequestFormConnectionPicked('c1'))
        ..add(const AccessRequestFormLevelPicked('write'))
        ..add(const AccessRequestFormReasonChanged('  For the report  '));
      await settle();

      expect(
        readyState(bloc),
        AccessRequestFormReady(
          connections: connections,
          connectionId: 'c1',
          level: 'write',
          reason: '  For the report  ',
        ),
      );
      await bloc.close();
    });

    test('a connection with a pending request cannot be picked', () async {
      final bloc = await ready();

      bloc.add(const AccessRequestFormConnectionPicked('c5'));
      await settle();

      expect(readyState(bloc).connectionId, isNull);
      await bloc.close();
    });

    test('a connection held at write cannot be picked', () async {
      final bloc = await ready();

      bloc.add(const AccessRequestFormConnectionPicked('c4'));
      await settle();

      expect(readyState(bloc).connectionId, isNull);
      await bloc.close();
    });

    test('write cannot be picked on a connection without a write credential', () async {
      final bloc = await ready();

      bloc
        ..add(const AccessRequestFormConnectionPicked('c2'))
        ..add(const AccessRequestFormLevelPicked('write'));
      await settle();

      expect(readyState(bloc).level, isNull);
      await bloc.close();
    });

    test('picking a connection that cannot take the chosen level clears the level', () async {
      final bloc = await ready();
      bloc
        ..add(const AccessRequestFormConnectionPicked('c1'))
        ..add(const AccessRequestFormLevelPicked('write'));
      await settle();

      bloc.add(const AccessRequestFormConnectionPicked('c2'));
      await settle();

      expect(readyState(bloc).connectionId, 'c2');
      expect(readyState(bloc).level, isNull);
      await bloc.close();
    });

    test('read cannot be picked on a connection held at read', () async {
      final bloc = await ready();

      bloc
        ..add(const AccessRequestFormConnectionPicked('c3'))
        ..add(const AccessRequestFormLevelPicked('read'));
      await settle();

      expect(readyState(bloc).connectionId, 'c3');
      expect(readyState(bloc).level, isNull);
      await bloc.close();
    });
  });

  group('submit', () {
    Future<AccessRequestFormBloc> filled({String reason = 'For the report'}) async {
      final bloc = await ready();
      bloc
        ..add(const AccessRequestFormConnectionPicked('c1'))
        ..add(const AccessRequestFormLevelPicked('read'))
        ..add(AccessRequestFormReasonChanged(reason));
      await settle();
      return bloc;
    }

    test('an incomplete draft is not sent and names what is missing', () async {
      final bloc = await ready();

      bloc.add(const AccessRequestFormSendRequested());
      await settle();

      expect(
        readyState(bloc).submission,
        const SubmissionIncomplete({
          AccessRequestField.connection,
          AccessRequestField.level,
          AccessRequestField.reason,
        }),
      );
      verifyNever(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      );
      await bloc.close();
    });

    test('a reason of blanks counts as missing', () async {
      final bloc = await filled(reason: '   \n ');

      bloc.add(const AccessRequestFormSendRequested());
      await settle();

      expect(readyState(bloc).submission, const SubmissionIncomplete({AccessRequestField.reason}));
      await bloc.close();
    });

    test('a reason over 500 characters after trimming is not sent', () async {
      final bloc = await filled(reason: ' ${'a' * 501} ');

      bloc.add(const AccessRequestFormSendRequested());
      await settle();

      expect(readyState(bloc).submission, const SubmissionIncomplete({AccessRequestField.reason}));
      await bloc.close();
    });

    test('a complete draft emits Sending, then Submitted with the request', () async {
      answerCreate(Success(created));
      final bloc = await filled();
      final states = bloc.stream.take(2).toList();

      bloc.add(const AccessRequestFormSendRequested());

      expect(await states, [
        AccessRequestFormReady(
          connections: connections,
          connectionId: 'c1',
          level: 'read',
          reason: 'For the report',
          submission: const SubmissionSending(),
        ),
        AccessRequestFormSubmitted(created),
      ]);
      verify(() => repository.create(connectionId: 'c1', level: 'read', reason: 'For the report')).called(1);
      await bloc.close();
    });

    test('a second Send while one is out is dropped', () async {
      final slow = Completer<Result<MyAccessRequest>>();
      when(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) => slow.future);
      final bloc = await filled();

      bloc
        ..add(const AccessRequestFormSendRequested())
        ..add(const AccessRequestFormSendRequested());
      await settle();
      slow.complete(Success(created));
      await bloc.stream.firstWhere((state) => state is AccessRequestFormSubmitted);

      verify(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      ).called(1);
      await bloc.close();
    });

    test('the draft cannot be edited while a request is out', () async {
      final slow = Completer<Result<MyAccessRequest>>();
      when(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) => slow.future);
      final bloc = await filled();
      bloc.add(const AccessRequestFormSendRequested());
      await settle();

      bloc.add(const AccessRequestFormReasonChanged('something else'));
      await settle();

      expect(readyState(bloc).reason, 'For the report');
      slow.complete(Success(created));
      await bloc.close();
    });

    for (final (name, code, field) in [
      ('a 400 on reason', AppErrorCode.platformAccessRequestReasonRefused, AccessRequestField.reason),
      ('a 400 on level', AppErrorCode.platformGrantLevelRefused, AccessRequestField.level),
      ('409 pending', AppErrorCode.platformAccessRequestPending, null),
      ('409 already granted', AppErrorCode.platformAccessAlreadyGranted, null),
      ('a transport failure', AppErrorCode.platformUnreachable, null),
    ]) {
      test('$name is a refusal that keeps the draft fields', () async {
        answerCreate(Failure(ValidationError('refused', code: code.key)));
        final bloc = await filled();
        bloc.add(const AccessRequestFormSendRequested());

        await bloc.stream.firstWhere(
          (state) => state is AccessRequestFormReady && state.submission is SubmissionRefused,
        );

        expect(
          readyState(bloc),
          AccessRequestFormReady(
            connections: connections,
            connectionId: 'c1',
            level: 'read',
            reason: 'For the report',
            submission: SubmissionRefused(errorCode: code, field: field),
          ),
        );
        await bloc.close();
      });
    }

    test('Send after a refusal sends once more, and only because the user asked', () async {
      answerCreate(Failure(NetworkError('down', code: AppErrorCode.platformUnreachable.key)));
      final bloc = await filled();
      bloc.add(const AccessRequestFormSendRequested());
      await bloc.stream.firstWhere((state) => state is AccessRequestFormReady && state.submission is SubmissionRefused);
      answerCreate(Success(created));

      bloc.add(const AccessRequestFormSendRequested());
      await bloc.stream.firstWhere((state) => state is AccessRequestFormSubmitted);

      verify(
        () => repository.create(
          connectionId: any(named: 'connectionId'),
          level: any(named: 'level'),
          reason: any(named: 'reason'),
        ),
      ).called(2);
      await bloc.close();
    });

    test('editing the draft after a refusal clears the refusal and keeps the rest', () async {
      answerCreate(Failure(ValidationError('refused', code: AppErrorCode.platformAccessRequestReasonRefused.key)));
      final bloc = await filled();
      bloc.add(const AccessRequestFormSendRequested());
      await bloc.stream.firstWhere((state) => state is AccessRequestFormReady && state.submission is SubmissionRefused);

      bloc.add(const AccessRequestFormReasonChanged('Another reason'));
      await settle();

      expect(readyState(bloc).submission, const SubmissionIdle());
      expect(readyState(bloc).reason, 'Another reason');
      expect(readyState(bloc).connectionId, 'c1');
      await bloc.close();
    });
  });
}
