@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';
import 'package:libredb_mobile/shared/widgets/platform_identity_scope.dart';

const _identity = PlatformIdentity(
  id: 'u1',
  email: 'admin@example.org',
  name: 'Platform Admin',
  roles: ['PLATFORM_ADMIN'],
  permissions: [],
  tenant: PlatformTenant(id: 't1', name: 'Example Org', slug: 'example-org'),
);

void _noRetry() {}

void main() {
  testWidgets('of answers the identity, the failure and the retry of the scope above', (tester) async {
    var retries = 0;
    void retry() => retries++;
    PlatformIdentityScope? found;
    await tester.pumpWidget(
      PlatformIdentityScope(
        identity: _identity,
        failed: false,
        onRetry: retry,
        child: Builder(
          builder: (context) {
            found = PlatformIdentityScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(found!.identity, _identity);
    expect(found!.failed, isFalse);
    found!.onRetry();
    expect(retries, 1);
  });

  testWidgets('a dependent rebuilds when the identity or the failure changes, and only then', (tester) async {
    _ScopeReader.builds = 0;
    Future<void> pumpScope(PlatformIdentity? identity, {bool failed = false}) => tester.pumpWidget(
      PlatformIdentityScope(identity: identity, failed: failed, onRetry: _noRetry, child: const _ScopeReader()),
    );

    await pumpScope(null);
    expect(_ScopeReader.builds, 1);

    await pumpScope(null);
    expect(_ScopeReader.builds, 1, reason: 'the same scope must not rebuild the const child');

    await pumpScope(null, failed: true);
    expect(_ScopeReader.builds, 2);

    await pumpScope(_identity);
    expect(_ScopeReader.builds, 3);

    await pumpScope(_identity);
    expect(_ScopeReader.builds, 3, reason: 'an equal identity must not rebuild the const child');
  });

  testWidgets('of throws a FlutterError that names the Platform shell without a scope above', (tester) async {
    Object? error;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          try {
            PlatformIdentityScope.of(context);
          } catch (e) {
            error = e;
          }
          return const SizedBox();
        },
      ),
    );

    expect(error, isA<FlutterError>().having((e) => e.toString(), 'text', contains('Platform shell')));
  });
}

/// A const dependent of the scope that counts its builds, so it rebuilds only when the scope notifies it.
class _ScopeReader extends StatelessWidget {
  const _ScopeReader();

  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    PlatformIdentityScope.of(context);
    return const SizedBox();
  }
}
