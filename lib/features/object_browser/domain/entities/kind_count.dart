import 'package:equatable/equatable.dart';

/// How many objects of one kind a container holds.
sealed class KindCount extends Equatable {
  const KindCount();
}

/// A count. With [sampledFrom] set it is a floor, shown as "n+".
final class KindCounted extends KindCount {
  const KindCounted(this.count, {this.sampledFrom});

  final int count;
  final String? sampledFrom;

  bool get isFloor => sampledFrom != null;

  @override
  List<Object?> get props => [count, sampledFrom];
}

/// The engine could not count them, for [reason], such as a missing privilege.
final class KindCountUnavailable extends KindCount {
  const KindCountUnavailable(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}
