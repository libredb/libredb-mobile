import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

/// How the editor colours the text it holds.
enum EditorHighlighting { sql, json, plain }

/// The statement language of a connection's engine, as the editor shows it: the colouring of the text and the name of
/// the language beside the field.
final class EditorLanguage extends Equatable {
  const EditorLanguage({required this.label, required this.highlighting});

  /// The engine's `queryDialect`, or its `queryLanguage` when it declares none, as Studio names it.
  final String label;

  final EditorHighlighting highlighting;

  /// The language of [meta]. A declared dialect is read before the language, as Studio's web editor does
  /// (`src/lib/editor/tab-language.ts` at c9989a6b5), because Redis, etcd and Kafka declare `queryLanguage: "json"`
  /// while speaking neither JSON nor SQL; such a dialect, and any language other than SQL and JSON, is plain text.
  factory EditorLanguage.of(ProviderMeta meta) {
    final dialect = meta.queryDialect;
    if (dialect != null) return EditorLanguage(label: dialect, highlighting: EditorHighlighting.plain);
    return EditorLanguage(
      label: meta.queryLanguage,
      highlighting: switch (meta.queryLanguage) {
        _ when meta.isSql => EditorHighlighting.sql,
        'json' => EditorHighlighting.json,
        _ => EditorHighlighting.plain,
      },
    );
  }

  @override
  List<Object?> get props => [label, highlighting];
}
