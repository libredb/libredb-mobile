import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockICollapsedSectionsRepository repository;

  setUp(() {
    repository = MockICollapsedSectionsRepository();
    when(() => repository.write(any())).thenAnswer((_) async {});
  });

  CollapsedSectionsCubit build() => CollapsedSectionsCubit(repository: repository);

  test('starts with every section expanded', () {
    expect(build().state, const CollapsedSectionsState());
  });

  blocTest<CollapsedSectionsCubit, CollapsedSectionsState>(
    'restores the sections collapsed on this device',
    setUp: () => when(() => repository.read()).thenAnswer((_) async => {'group:Sales'}),
    build: build,
    act: (cubit) => cubit.restore(),
    expect: () => const [
      CollapsedSectionsState({'group:Sales'}),
    ],
  );

  blocTest<CollapsedSectionsCubit, CollapsedSectionsState>(
    'keeps every section expanded when the stored state cannot be read',
    setUp: () => when(() => repository.read()).thenThrow(const FormatException('not a list')),
    build: build,
    act: (cubit) => cubit.restore(),
    expect: () => const <CollapsedSectionsState>[],
  );

  blocTest<CollapsedSectionsCubit, CollapsedSectionsState>(
    'collapses and expands a section and stores each change',
    build: build,
    act: (cubit) async {
      await cubit.toggle('group:Sales');
      await cubit.toggle('other');
      await cubit.toggle('group:Sales');
    },
    expect: () => const [
      CollapsedSectionsState({'group:Sales'}),
      CollapsedSectionsState({'group:Sales', 'other'}),
      CollapsedSectionsState({'other'}),
    ],
    verify: (_) {
      verifyInOrder([
        () => repository.write({'group:Sales'}),
        () => repository.write({'group:Sales', 'other'}),
        () => repository.write({'other'}),
      ]);
    },
  );

  blocTest<CollapsedSectionsCubit, CollapsedSectionsState>(
    'keeps the change on screen when the device refuses to store it',
    setUp: () => when(() => repository.write(any())).thenThrow(StateError('refused')),
    build: build,
    act: (cubit) => cubit.toggle('other'),
    expect: () => const [
      CollapsedSectionsState({'other'}),
    ],
  );

  blocTest<CollapsedSectionsCubit, CollapsedSectionsState>(
    'a toggle made before the stored state arrives is not overwritten by it',
    setUp: () => when(() => repository.read()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return {'group:Finance'};
    }),
    build: build,
    act: (cubit) async {
      final restoring = cubit.restore();
      await cubit.toggle('other');
      await restoring;
    },
    expect: () => const [
      CollapsedSectionsState({'other'}),
    ],
  );
}
