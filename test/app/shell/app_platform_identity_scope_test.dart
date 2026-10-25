@Tags(['widget'])
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/app_platform_identity_scope.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/widgets/platform_identity_scope.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

const _identity = PlatformIdentity(
  id: 'u1',
  email: 'admin@example.org',
  roles: ['PLATFORM_ADMIN'],
  permissions: [],
  tenant: PlatformTenant(id: 't1', name: 'Example Org', slug: 'example-org'),
);

void main() {
  late MockPlatformIdentityCubit identity;
  late StreamController<PlatformIdentityState> states;
  final seen = <PlatformIdentityScope>[];

  // Made inside the test body, so the states it streams are delivered in the test's fake async zone.
  Future<void> pumpScope(WidgetTester tester) {
    identity = MockPlatformIdentityCubit();
    when(() => identity.load()).thenAnswer((_) async {});
    states = StreamController<PlatformIdentityState>();
    addTearDown(states.close);
    seen.clear();
    whenListen(identity, states.stream, initialState: const PlatformIdentityLoading());
    return tester.pumpWidget(
      BlocProvider<PlatformIdentityCubit>.value(
        value: identity,
        child: AppPlatformIdentityScope(
          child: Builder(
            builder: (context) {
              seen.add(PlatformIdentityScope.of(context));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  Future<void> emit(WidgetTester tester, PlatformIdentityState state) async {
    states.add(state);
    await tester.pump();
    await tester.pump();
  }

  (PlatformIdentity?, bool) last() => (seen.last.identity, seen.last.failed);

  testWidgets('maps every PlatformIdentityCubit state', (tester) async {
    await pumpScope(tester);
    expect(last(), (null, false), reason: 'Loading');

    await emit(tester, const PlatformIdentityLoaded(_identity));
    expect(last(), (_identity, false), reason: 'Loaded');

    await emit(tester, const PlatformIdentityFailure(AppErrorCode.platformInternalError));
    expect(last(), (null, true), reason: 'Failure');

    await emit(tester, const PlatformIdentityInitial());
    expect(last(), (null, false), reason: 'Initial');
  });

  testWidgets('its retry loads the identity again', (tester) async {
    await pumpScope(tester);
    await emit(tester, const PlatformIdentityFailure(AppErrorCode.platformInternalError));

    seen.last.onRetry();

    verify(() => identity.load()).called(1);
  });
}
