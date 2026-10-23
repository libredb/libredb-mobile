import 'package:equatable/equatable.dart';

/// One row of the key tree: a folder or a key, drawn at [depth].
sealed class KeyTreeRow extends Equatable {
  const KeyTreeRow({required this.label, required this.depth});

  /// The row's own segment; a folder's ends in the separator.
  final String label;
  final int depth;
}

/// A folder the held keys were grouped into: every key that starts with [prefix].
final class KeyTreeFolder extends KeyTreeRow {
  const KeyTreeFolder({
    required this.prefix,
    required super.label,
    required super.depth,
    required this.count,
    required this.expanded,
  });

  /// The full prefix the folder stands for, ending in the separator.
  final String prefix;

  /// How many held keys are under the folder.
  final int count;

  final bool expanded;

  @override
  List<Object?> get props => [prefix, label, depth, count, expanded];
}

/// A key and its value type, when a page read it.
final class KeyTreeKey extends KeyTreeRow {
  const KeyTreeKey({required this.key, required super.label, required super.depth, this.type});

  final String key;
  final String? type;

  @override
  List<Object?> get props => [key, label, depth, type];
}

/// The rows of [keys] grouped into folders by [separator], as Studio's key panel groups a walk with no levels: a
/// folder for each run of segments before a key's last one, with how many keys are under it. Only the folders whose
/// prefix is in [expanded] show their rows. At each level the folders come first, then the keys, each sorted by name.
List<KeyTreeRow> keyTreeRows(
  List<String> keys,
  Map<String, String> types,
  String separator, {
  Set<String> expanded = const {},
}) {
  final root = _Node('');
  for (final key in keys) {
    final segments = separator.isEmpty ? [key] : key.split(separator);
    var node = root;
    for (final segment in segments.take(segments.length - 1)) {
      node = node.folders.putIfAbsent(segment, () => _Node('${node.prefix}$segment$separator'));
      node.count++;
    }
    node.keys[key] = segments.last;
  }
  final rows = <KeyTreeRow>[];
  void walk(_Node node, int depth) {
    for (final segment in node.folders.keys.toList()..sort()) {
      final folder = node.folders[segment]!;
      final open = expanded.contains(folder.prefix);
      rows.add(
        KeyTreeFolder(
          prefix: folder.prefix,
          label: '$segment$separator',
          depth: depth,
          count: folder.count,
          expanded: open,
        ),
      );
      if (open) walk(folder, depth + 1);
    }
    for (final key in node.keys.keys.toList()..sort()) {
      final label = node.keys[key]!;
      rows.add(KeyTreeKey(key: key, label: label.isEmpty ? key : label, depth: depth, type: types[key]));
    }
  }

  walk(root, 0);
  return rows;
}

class _Node {
  _Node(this.prefix);

  final String prefix;
  final Map<String, _Node> folders = {};

  /// Each key directly under this folder and its last segment.
  final Map<String, String> keys = {};
  int count = 0;
}
