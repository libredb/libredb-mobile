import 'package:equatable/equatable.dart';

/// An answer of Studio and the time Studio gave it, which a kept answer carries along, so a screen showing it offline
/// names when Studio said it rather than when the screen got it.
class Answered<T> extends Equatable {
  const Answered(this.value, {required this.at});

  final T value;

  /// When Studio's answer arrived.
  final DateTime at;

  @override
  List<Object?> get props => [value, at];
}
