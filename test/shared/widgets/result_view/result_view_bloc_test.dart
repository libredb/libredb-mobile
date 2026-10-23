import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';

QueryResult _result(List<Map<String, Object?>> rows) => QueryResult(
  fields: const ['id', 'email'],
  rows: rows,
  rowCount: rows.length,
  executionTime: const Duration(milliseconds: 3),
);

void main() {
  final policy = MaskingPolicy.forRole(const StudioUserRole());
  final first = maskResult(
    _result(const [
      {'id': 1, 'email': 'alice@example.com'},
    ]),
    policy,
  );
  final second = maskResult(
    _result(const [
      {'id': 2, 'email': 'bob@example.com'},
    ]),
    policy,
  );

  test('starts with the masked result and its masked columns, and keeps the policy it was masked with', () {
    final bloc = ResultViewBloc(masked: first, policy: policy);
    addTearDown(bloc.close);

    expect(bloc.state, ResultViewLoaded(result: first.result, maskedColumns: first.maskedColumns));
    expect(bloc.policy, policy);
    expect(first.maskedColumns, {'email'});
    expect(bloc.state.toString(), isNot(contains('alice@example.com')));
  });

  blocTest<ResultViewBloc, ResultViewState>(
    'a result the caller ran again replaces the one shown',
    build: () => ResultViewBloc(masked: first, policy: policy),
    act: (bloc) => bloc.add(ResultViewReplaced(second)),
    expect: () => [ResultViewLoaded(result: second.result, maskedColumns: second.maskedColumns)],
  );

  blocTest<ResultViewBloc, ResultViewState>(
    'the same result again changes nothing',
    build: () => ResultViewBloc(masked: first, policy: policy),
    act: (bloc) => bloc.add(ResultViewReplaced(first)),
    expect: () => const <ResultViewState>[],
  );
}
