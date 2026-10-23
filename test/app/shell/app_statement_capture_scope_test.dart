@Tags(['widget'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/app_statement_capture_scope.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';

import '../../mocks/mock_classes.dart';

void main() {
  Future<bool> recordsInFull(WidgetTester tester, ConnectionPolicyState state) async {
    final policy = MockConnectionPolicyCubit();
    whenListen(policy, const Stream<ConnectionPolicyState>.empty(), initialState: state);
    late bool answer;
    await tester.pumpWidget(
      BlocProvider<ConnectionPolicyCubit>.value(
        value: policy,
        child: AppStatementCaptureScope(
          child: Builder(
            builder: (context) {
              answer = StatementCaptureScope.recordsInFullOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return answer;
  }

  ConnectionPolicyLoaded loaded(String? capture) =>
      ConnectionPolicyLoaded(ConnectionPolicy(customConnections: false, governance: true, statementCapture: capture));

  testWidgets('records in full only while the loaded policy captures statements in full', (tester) async {
    expect(await recordsInFull(tester, loaded('full')), isTrue);
    expect(await recordsInFull(tester, loaded('redacted')), isFalse);
    expect(await recordsInFull(tester, loaded(null)), isFalse);
    expect(await recordsInFull(tester, const ConnectionPolicyInitial()), isFalse);
    expect(await recordsInFull(tester, const ConnectionPolicyLoading()), isFalse);
    expect(await recordsInFull(tester, const ConnectionPolicyFailure(AppErrorCode.generic)), isFalse);
  });
}
