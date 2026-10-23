import 'package:equatable/equatable.dart';

/// A result column that holds vectors, as Studio's `QueryResult.vectorColumns` declares it
/// (`src/lib/db/vector/types.ts` in Studio). A cell of a declared column holds its engine's native form; a column that
/// is not declared is shown as any other column, whatever its cells hold.
///
/// [kind], [dtype] and [sparseEncoding] are Studio's ids, kept as opaque strings so a newer Studio that adds one still
/// reads.
class VectorColumn extends Equatable {
  const VectorColumn({required this.kind, required this.dtype, required this.dimension, this.sparseEncoding});

  /// `dense`, `sparse` or `multi` today.
  final String kind;

  /// The element type: `float32`, `float64`, `float16`, `bfloat16`, `int8`, `uint8` or `binary` today.
  final String dtype;

  /// Elements per vector, bits for a binary vector, and the size of one row for a multivector; null for a sparse
  /// column and where the engine declares no dimension.
  final int? dimension;

  /// How a sparse cell is encoded (`index-map` or `indices-values` today): set on every sparse column and on no other.
  final String? sparseEncoding;

  @override
  List<Object?> get props => [kind, dtype, dimension, sparseEncoding];
}
