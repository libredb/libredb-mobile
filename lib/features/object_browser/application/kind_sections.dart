import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

/// One kind of a container and how many objects of it the container holds.
class KindRow extends Equatable {
  const KindRow({required this.kind, required this.count});

  final ObjectKind kind;
  final KindCount count;

  @override
  List<Object?> get props => [kind, count];
}

/// The kind rows drawn under one [group] folder, or a run of kinds in no folder when [group] is null.
class KindSection extends Equatable {
  const KindSection({this.group, required this.rows});

  final ObjectKindGroup? group;
  final List<KindRow> rows;

  @override
  List<Object?> get props => [group, rows];
}

/// The rows of a container's kind screen, in the order the engine declares its kinds.
///
/// A kind shows only when [counts] names it, the container holds it ([containerKinds], when the container names its
/// kinds) and it is not one only the key browser lists. Kinds that share a `group` id are drawn together under the
/// group's label, where the first of them is declared.
List<KindSection> kindSectionsOf(ProviderMeta meta, Map<String, KindCount> counts, {List<String>? containerKinds}) {
  final sections = <KindSection>[];
  final grouped = <String, List<KindRow>>{};
  for (final kind in meta.objectKinds) {
    final count = counts[kind.id];
    if (count == null || kind.keyBrowserOnly) continue;
    if (containerKinds != null && !containerKinds.contains(kind.id)) continue;
    final row = KindRow(kind: kind, count: count);
    final group = kind.group;
    if (group == null) {
      final last = sections.isEmpty ? null : sections.last;
      if (last != null && last.group == null) {
        last.rows.add(row);
      } else {
        sections.add(KindSection(rows: [row]));
      }
      continue;
    }
    final rows = grouped[group.id];
    if (rows != null) {
      rows.add(row);
    } else {
      final rows = [row];
      grouped[group.id] = rows;
      sections.add(KindSection(group: group, rows: rows));
    }
  }
  return [for (final section in sections) KindSection(group: section.group, rows: List.unmodifiable(section.rows))];
}
