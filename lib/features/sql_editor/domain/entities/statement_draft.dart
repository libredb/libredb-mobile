import 'package:equatable/equatable.dart';

/// The text a user typed in the editor for one connection, kept on the device until they run or change it, and the
/// database it was typed for on a server-level connection.
class StatementDraft extends Equatable {
  const StatementDraft({required this.text, this.catalog});

  final String text;
  final String? catalog;

  @override
  List<Object?> get props => [text, catalog];

  /// Prints the length, never the text, which can hold customer data in its literals.
  @override
  String toString() => 'StatementDraft(${text.length} characters, catalog: ${catalog != null})';
}

/// Whether the store kept a draft.
enum DraftSaveOutcome {
  /// The draft is saved.
  kept,

  /// The draft is longer than the store keeps, so it was not saved, and the connection's earlier draft was removed so
  /// that it is never restored in its place.
  notKept,
}
