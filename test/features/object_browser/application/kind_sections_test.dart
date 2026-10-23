import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/object_browser/application/kind_sections.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

void main() {
  const workloads = ObjectKindGroup(id: 'workloads', label: 'Workloads');
  const network = ObjectKindGroup(id: 'network', label: 'Network');

  ObjectKind kind(String id, {ObjectKindGroup? group, bool keyBrowserOnly = false}) => ObjectKind(
    id: id,
    role: 'relation',
    label: id,
    labelPlural: '${id}s',
    group: group,
    keyBrowserOnly: keyBrowserOnly,
  );

  ProviderMeta meta(List<ObjectKind> kinds) =>
      ProviderMeta(queryLanguage: 'json', schemaRefreshPattern: 'x', containerLevels: const [], objectKinds: kinds);

  /// Each section as its group label, or `-` for none, and its kind ids.
  List<String> shape(List<KindSection> sections) => [
    for (final section in sections)
      '${section.group?.label ?? '-'}: ${section.rows.map((row) => row.kind.id).join(', ')}',
  ];

  test('groups kinds under their group label where the first of them is declared, in declaration order', () {
    final sections = kindSectionsOf(
      meta([
        kind('namespace'),
        kind('pod', group: workloads),
        kind('service', group: network),
        kind('deployment', group: workloads),
        kind('secret'),
      ]),
      const {
        'namespace': KindCounted(3),
        'pod': KindCounted(12),
        'service': KindCounted(4),
        'deployment': KindCounted(2),
        'secret': KindCounted(9),
      },
    );

    expect(shape(sections), ['-: namespace', 'Workloads: pod, deployment', 'Network: service', '-: secret']);
  });

  test('leaves out a kind the answer does not name and a kind only the key browser lists', () {
    final sections = kindSectionsOf(meta([kind('table'), kind('view'), kind('key', keyBrowserOnly: true)]), const {
      'table': KindCounted(1),
      'key': KindCounted(100),
    });

    expect(shape(sections), ['-: table']);
  });

  test('keeps only the kinds a container names, when it names them', () {
    final sections = kindSectionsOf(
      meta([kind('table'), kind('view')]),
      const {'table': KindCounted(1), 'view': KindCountUnavailable('Refused.')},
      containerKinds: const ['view'],
    );

    expect(shape(sections), ['-: view']);
  });
}
