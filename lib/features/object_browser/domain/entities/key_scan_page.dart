import 'package:equatable/equatable.dart';

/// One page of a key-value engine's keys.
class KeyScanPage extends Equatable {
  const KeyScanPage({
    required this.keys,
    required this.cursor,
    required this.types,
    required this.total,
    this.clustered,
    this.skipped,
    this.readOutcome,
    this.prefixes,
  });

  /// The keys of this page, which may repeat keys of earlier pages.
  final List<String> keys;

  /// What to send for the next page, exactly as it came, decimal or opaque; `0` means the walk reached the end.
  final String cursor;

  /// The value type of each key whose type could be read.
  final Map<String, String> types;

  /// What the engine counts, in the scope its `keyScan.totalScope` names; not read under `none`.
  final int total;

  /// Whether the keys and the total describe one node of a clustered deployment; null when the server did not say.
  final bool? clustered;

  /// The keys this page read and left out, because no name a row could carry addresses them.
  final KeyScanSkipped? skipped;

  /// What the engine can and cannot establish about the read's completeness; null claims nothing either way.
  final KeyReadOutcome? readOutcome;

  /// The folders of a level page, each a full prefix ending in the separator; null on a walk of keys.
  final List<String>? prefixes;

  bool get isLast => cursor == '0';

  @override
  List<Object?> get props => [keys, cursor, types, total, clustered, skipped, readOutcome, prefixes];
}

/// How many keys a page left out, and Studio's words for why.
class KeyScanSkipped extends Equatable {
  const KeyScanSkipped({required this.count, required this.reason});

  final int count;
  final String reason;

  @override
  List<Object?> get props => [count, reason];
}

/// What an engine can say about whether a read is complete.
class KeyReadOutcome extends Equatable {
  const KeyReadOutcome({required this.scope, required this.endReason, this.provenLoss = const []});

  /// `incomplete` when the engine can prove the read is short, `unknown` when it cannot tell.
  final String scope;

  /// Why the read stopped, in the engine's own words.
  final String endReason;

  /// What the engine can show was lost, one sentence each; empty never means nothing was lost.
  final List<String> provenLoss;

  bool get isIncomplete => scope == 'incomplete';

  @override
  List<Object?> get props => [scope, endReason, provenLoss];
}
