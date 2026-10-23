import 'package:equatable/equatable.dart';

/// The definition of a view, function or other object with source, in up to eight parts (a package's specification
/// and body, for one).
class ObjectSource extends Equatable {
  const ObjectSource({required this.path, required this.kind, required this.parts});

  final List<String> path;
  final String kind;
  final List<SourcePart> parts;

  @override
  List<Object?> get props => [path, kind, parts];
}

sealed class SourcePart extends Equatable {
  const SourcePart({required this.id, required this.label});

  final String id;

  /// The engine's own word for the part, such as Package body.
  final String label;
}

/// Where a part's text comes from.
enum SourceOrigin {
  /// The text the engine keeps, as it was written.
  stored,

  /// Text the engine or Studio rebuilt from the catalog, not the stored text.
  regenerated,

  /// Text Studio drew from the object's data, such as a document as JSON.
  rendered,
}

/// Studio cut a part's text: [limit] counts what the producer counts, characters at the route's bound and collection
/// ids for a Firestore document's subcollections, and only [reason], the producer's own sentence, names that unit.
/// [limit] is any number, as Studio's client accepts, and an int when it is whole.
class SourceTruncation extends Equatable {
  const SourceTruncation({required this.limit, required this.reason});

  final num limit;
  final String reason;

  @override
  List<Object?> get props => [limit, reason];
}

final class SourceText extends SourcePart {
  const SourceText({
    required super.id,
    required super.label,
    required this.text,
    required this.language,
    required this.origin,
    this.complete = true,
    this.truncated,
  });

  final String text;

  /// The language to highlight it as, such as `pgsql`.
  final String language;

  final SourceOrigin origin;

  /// Whether the text is the whole definition, not a part of it such as the SELECT of a view.
  final bool complete;

  /// Set when Studio cut the text.
  final SourceTruncation? truncated;

  /// Whether the text is not the one the engine keeps.
  bool get isRegenerated => origin != SourceOrigin.stored;

  @override
  List<Object?> get props => [id, label, text, language, origin, complete, truncated];

  /// Leaves the text out, which is the user's definition and never goes into a log.
  @override
  String toString() =>
      'SourceText($id, $label, $language, $origin, complete: $complete, truncated: $truncated, '
      '${text.length} characters)';
}

/// A part the engine could not read, with its own sentence why.
final class SourceUnavailable extends SourcePart {
  const SourceUnavailable({required super.id, required super.label, required this.reason});

  final String reason;

  @override
  List<Object?> get props => [id, label, reason];
}

/// A neutral fact about the object in place of a part, such as why the engine shows nothing here; never a failure.
final class SourceStatement extends SourcePart {
  const SourceStatement({required super.id, required super.label, required this.statement});

  final String statement;

  @override
  List<Object?> get props => [id, label, statement];
}
