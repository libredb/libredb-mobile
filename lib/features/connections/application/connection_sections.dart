import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';
import 'package:libredb_mobile/shared/utils/search_fold.dart';

/// The rows of one operator `group`, or of every row without one (the Other section) when [group] is null.
final class ConnectionSection extends Equatable {
  const ConnectionSection({required this.group, required this.connections});

  final String? group;
  final List<StudioConnection> connections;

  /// Names the section in the stored collapsed state; a group called `other` and the Other section never share one.
  String get key => group == null ? 'other' : 'group:$group';

  @override
  List<Object?> get props => [group, connections];
}

/// Splits [connections] into sections by `group`: sections and rows sorted by name, case and the Turkish i ignored and
/// a Turkish letter next to its base letter, with the Other section, for rows without a group or with a blank one, last.
List<ConnectionSection> groupConnections(Iterable<StudioConnection> connections) {
  final byGroup = <String?, List<StudioConnection>>{};
  for (final connection in connections) {
    final group = connection.group;
    final key = group == null || group.trim().isEmpty ? null : group;
    byGroup.putIfAbsent(key, () => []).add(connection);
  }
  final groups = byGroup.keys.whereType<String>().toList()..sort(_compareNames);
  return [
    for (final group in [...groups, if (byGroup.containsKey(null)) null])
      ConnectionSection(group: group, connections: byGroup[group]!..sort(_compareConnections)),
  ];
}

/// The rows of [connections] whose name, database, host or group holds [query] (see [matchesSearch]) and, when
/// [environment] is set, whose environment is that one; in their order.
List<StudioConnection> filterConnections(
  List<StudioConnection> connections, {
  required String query,
  String? environment,
}) {
  return [
    for (final c in connections)
      if ((environment == null || c.environment == environment) &&
          matchesSearch(query, [c.name, c.database, c.host, c.group]))
        c,
  ];
}

/// The environments present in [connections], in Studio's order, then any other string sorted by name.
List<String> environmentsOf(Iterable<StudioConnection> connections) {
  final present = connections.map((c) => c.environment).whereType<String>().toSet();
  final unknown = present.where((e) => !StudioEnvironment.ordered.contains(e)).toList()..sort(_compareNames);
  return [...StudioEnvironment.ordered.where(present.contains), ...unknown];
}

/// Studio sorts with `localeCompare` (libredb-studio `src/lib/governance/visible.ts`), which places a Turkish letter
/// next to its base letter, so `Çanakkale` comes before `Denizli`; the folded code units alone would put it after `z`.
/// Other accented letters keep their code-unit order.
const _turkishBaseLetters = {'ç': 'c', 'ğ': 'g', 'ö': 'o', 'ş': 's', 'ü': 'u'};

String _sortKey(String folded) {
  var key = folded;
  _turkishBaseLetters.forEach((letter, base) => key = key.replaceAll(letter, base));
  return key;
}

/// By the base letters first, then by the folded name (a plain letter before its Turkish one), then as written.
int _compareNames(String a, String b) {
  final foldedA = foldForSearch(a);
  final foldedB = foldForSearch(b);
  final byBase = _sortKey(foldedA).compareTo(_sortKey(foldedB));
  if (byBase != 0) return byBase;
  final folded = foldedA.compareTo(foldedB);
  return folded != 0 ? folded : a.compareTo(b);
}

int _compareConnections(StudioConnection a, StudioConnection b) {
  final byName = _compareNames(a.name, b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}
