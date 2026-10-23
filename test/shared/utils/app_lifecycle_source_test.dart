import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';

void main() {
  testWidgets('the binding source tells each lifecycle change and the current state', (tester) async {
    final source = BindingAppLifecycleSource();
    addTearDown(source.dispose);
    final seen = <AppLifecycleState>[];
    final subscription = source.changes.listen(seen.add);
    addTearDown(subscription.cancel);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(seen, [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]);
    expect(source.current, AppLifecycleState.paused);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(source.current, AppLifecycleState.resumed);
  });

  test('hidden, paused and detached count as the background, resumed and inactive do not', () {
    expect(
      AppLifecycleState.values.where(isInBackground),
      unorderedEquals([AppLifecycleState.hidden, AppLifecycleState.paused, AppLifecycleState.detached]),
    );
    expect(isInBackground(null), isFalse);
  });
}
