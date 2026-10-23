part of 'key_value_bloc.dart';

sealed class KeyValueState extends Equatable {
  const KeyValueState();

  @override
  List<Object?> get props => const [];
}

final class KeyValueLoading extends KeyValueState {
  const KeyValueLoading();
}

/// The engine is not read through Redis's typed reads, so nothing ran.
final class KeyValueUnavailable extends KeyValueState {
  const KeyValueUnavailable();
}

/// An answer on screen: a value, the key's type, or that the key no longer exists.
sealed class KeyValueShown extends KeyValueState {
  const KeyValueShown({required this.loadedAt, required this.isRefreshing});

  /// When the answer was read; offline, the page shows it as what was loaded at this time.
  final DateTime loadedAt;

  final bool isRefreshing;

  KeyValueShown copyWith({required bool isRefreshing});
}

/// The typed read's answer, masked.
final class KeyValueLoaded extends KeyValueShown {
  const KeyValueLoaded({
    required this.read,
    required this.masked,
    required this.policy,
    required this.run,
    required super.loadedAt,
    super.isRefreshing = false,
  });

  /// The read that ran, with the type it read.
  final RedisKeyRead read;

  /// The answer, masked by [policy].
  final MaskedResult masked;

  /// The policy [masked] was masked with, for the result view.
  final MaskingPolicy policy;

  /// Which value answer this is, counted from one, so the page shows each answer as a result of its own.
  final int run;

  @override
  KeyValueLoaded copyWith({required bool isRefreshing}) => KeyValueLoaded(
    read: read,
    masked: masked,
    policy: policy,
    run: run,
    loadedAt: loadedAt,
    isRefreshing: isRefreshing,
  );

  @override
  List<Object?> get props => [read, masked, policy, run, loadedAt, isRefreshing];
}

/// Studio's answer to `TYPE <key>`: [type] as it came, and [readable], the one of the seven types it names, for which
/// 'Read value' runs the typed read; null for a type the app has no read for, such as a module type.
final class KeyValueTypeAnswered extends KeyValueShown {
  const KeyValueTypeAnswered({
    required this.type,
    required this.readable,
    required super.loadedAt,
    super.isRefreshing = false,
  });

  final String type;
  final String? readable;

  @override
  KeyValueTypeAnswered copyWith({required bool isRefreshing}) =>
      KeyValueTypeAnswered(type: type, readable: readable, loadedAt: loadedAt, isRefreshing: isRefreshing);

  @override
  List<Object?> get props => [type, readable, loadedAt, isRefreshing];
}

/// The key no longer exists: the read answered `(nil)` or `(empty list)` with no rows, or `TYPE` answered `none`.
final class KeyValueVanished extends KeyValueShown {
  const KeyValueVanished({required super.loadedAt, super.isRefreshing = false});

  @override
  KeyValueVanished copyWith({required bool isRefreshing}) =>
      KeyValueVanished(loadedAt: loadedAt, isRefreshing: isRefreshing);

  @override
  List<Object?> get props => [loadedAt, isRefreshing];
}

/// The key could not be read.
///
/// [error] is shown by the Browse failure view, and for `studio.query_error` the database's own words under it, on
/// screen only; [previous] is what was shown before a refresh that failed, which stays on screen under the error.
final class KeyValueFailure extends KeyValueState {
  const KeyValueFailure({required this.error, this.previous});

  final AppError error;
  final KeyValueShown? previous;

  @override
  List<Object?> get props => [error, previous];
}
