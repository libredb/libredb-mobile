import 'package:equatable/equatable.dart';

/// One page of a key-value engine's keys.
class KeyScanPage extends Equatable {
  const KeyScanPage({required this.keys, required this.cursor, required this.types, required this.total});

  /// The keys of this page, which may repeat keys of earlier pages.
  final List<String> keys;

  /// What to send for the next page; `0` means the walk reached the end.
  final String cursor;

  /// The value type of each key whose type could be read.
  final Map<String, String> types;

  /// The number of keys in the database.
  final int total;

  bool get isLast => cursor == '0';

  @override
  List<Object?> get props => [keys, cursor, types, total];
}
