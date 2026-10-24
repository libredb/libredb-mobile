part of 'remove_my_data_bloc.dart';

sealed class RemoveMyDataEvent extends Equatable {
  const RemoveMyDataEvent();

  @override
  List<Object?> get props => const [];
}

/// The user confirmed 'Remove my data', or asked to try it again.
final class RemoveMyDataRequested extends RemoveMyDataEvent {
  const RemoveMyDataRequested({required this.subject});

  /// The identity provider's subject of the signed-in user, from Studio's `GET /api/auth/me`.
  final String subject;

  @override
  List<Object?> get props => [subject];
}
