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
  final String label;
}

final class SourceText extends SourcePart {
  const SourceText({
    required super.id,
    required super.label,
    required this.text,
    required this.language,
    this.complete = true,
    this.truncated = false,
  });

  final String text;

  /// The language to highlight it as, such as `sql`.
  final String language;

  /// Whether the text is the whole definition rather than a part the engine regenerated.
  final bool complete;

  /// Studio cut the text at its size bound.
  final bool truncated;

  @override
  List<Object?> get props => [id, label, text, language, complete, truncated];
}

final class SourceUnavailable extends SourcePart {
  const SourceUnavailable({required super.id, required super.label, required this.reason});

  final String reason;

  @override
  List<Object?> get props => [id, label, reason];
}
