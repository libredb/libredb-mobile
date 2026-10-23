import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_store.dart';

import '../../../support/printed_lines.dart';

void main() {
  test('shows cards until the stored mode is read, then the stored mode', () async {
    final cubit = ResultViewModeCubit(store: _MemoryStore(ResultViewMode.table));
    addTearDown(cubit.close);

    expect(cubit.state, ResultViewMode.cards);
    await cubit.restore();

    expect(cubit.state, ResultViewMode.table);
  });

  test('a device that stored no mode shows cards', () async {
    final cubit = ResultViewModeCubit(store: _MemoryStore(null));
    addTearDown(cubit.close);

    await cubit.restore();

    expect(cubit.state, ResultViewMode.cards);
  });

  test('an unreadable store shows cards and logs one warn line', () async {
    final cubit = ResultViewModeCubit(store: _ThrowingStore());
    addTearDown(cubit.close);

    final lines = await printedLines(cubit.restore);

    expect(cubit.state, ResultViewMode.cards);
    expect(lines.where((line) => line.contains('ResultViewModeCubit')), [contains('[W]')]);
  });

  test('a choice is shown and stored', () async {
    final store = _MemoryStore(null);
    final cubit = ResultViewModeCubit(store: store);
    addTearDown(cubit.close);

    await cubit.select(ResultViewMode.table);

    expect(cubit.state, ResultViewMode.table);
    expect(store.mode, ResultViewMode.table);
  });

  test('a choice the device refuses to store still applies, with one warn line', () async {
    final cubit = ResultViewModeCubit(store: _ThrowingStore());
    addTearDown(cubit.close);

    final lines = await printedLines(() => cubit.select(ResultViewMode.table));

    expect(cubit.state, ResultViewMode.table);
    expect(lines.where((line) => line.contains('ResultViewModeCubit')), [contains('[W]')]);
  });

  test('a choice made while the stored mode is read is not replaced by it', () async {
    final store = _SlowStore();
    final cubit = ResultViewModeCubit(store: store);
    addTearDown(cubit.close);

    final restoring = cubit.restore();
    await cubit.select(ResultViewMode.table);
    store.answer.complete(ResultViewMode.cards);
    await restoring;

    expect(cubit.state, ResultViewMode.table);
  });
}

class _MemoryStore implements IResultViewModeStore {
  _MemoryStore(this.mode);

  ResultViewMode? mode;

  @override
  Future<ResultViewMode?> read() async => mode;

  @override
  Future<void> write(ResultViewMode mode) async => this.mode = mode;
}

class _ThrowingStore implements IResultViewModeStore {
  @override
  Future<ResultViewMode?> read() async => throw const FormatException('result_view_mode is not a view mode');

  @override
  Future<void> write(ResultViewMode mode) async => throw StateError('the device refused to store result_view_mode');
}

class _SlowStore implements IResultViewModeStore {
  final answer = Completer<ResultViewMode?>();

  @override
  Future<ResultViewMode?> read() => answer.future;

  @override
  Future<void> write(ResultViewMode mode) async {}
}
