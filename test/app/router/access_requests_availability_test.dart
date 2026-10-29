@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/router/access_requests_availability.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

void main() {
  const governed = ConnectionPolicy(customConnections: false, governance: true);
  const ungoverned = ConnectionPolicy(customConnections: true, governance: false);

  Future<bool> askWith(WidgetTester tester, {required AppConfig config, required ConnectionPolicyState policy}) async {
    final cubit = MockConnectionPolicyCubit();
    when(() => cubit.state).thenReturn(policy);
    late bool answer;
    await tester.pumpWidget(
      RepositoryProvider<AppConfig>.value(
        value: config,
        child: BlocProvider<ConnectionPolicyCubit>.value(
          value: cubit,
          child: Builder(
            builder: (context) {
              answer = accessRequestsAvailable(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return answer;
  }

  for (final (platform, policy, expected) in [
    (true, const ConnectionPolicyLoaded(governed), true),
    (true, const ConnectionPolicyLoaded(ungoverned), false),
    (false, const ConnectionPolicyLoaded(governed), false),
    (false, const ConnectionPolicyLoaded(ungoverned), false),
    (true, const ConnectionPolicyInitial(), false),
    (true, const ConnectionPolicyLoading(), false),
    (true, const ConnectionPolicyFailure(AppErrorCode.generic), false),
  ]) {
    testWidgets('with ${platform ? 'a' : 'no'} Platform target and the policy ${policy.runtimeType} '
        '${policy is ConnectionPolicyLoaded ? 'governance ${policy.policy.governance}' : ''}: $expected', (
      tester,
    ) async {
      final config = platform ? const AppConfig.test() : const AppConfig.local();

      expect(await askWith(tester, config: config, policy: policy), expected);
    });
  }
}
