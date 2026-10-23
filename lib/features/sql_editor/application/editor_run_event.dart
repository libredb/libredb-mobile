part of 'editor_run_bloc.dart';

sealed class EditorRunEvent extends Equatable {
  const EditorRunEvent();

  @override
  List<Object?> get props => const [];
}

/// Run [text] for [role], the role Studio names now, whose policy masks the answer.
final class EditorRunRequested extends EditorRunEvent {
  const EditorRunRequested({required this.text, required this.role});

  final String text;
  final StudioRole? role;

  @override
  List<Object?> get props => [text, role];

  /// Prints the length, never the text, which can hold customer data in its literals.
  @override
  String toString() => 'EditorRunRequested(${text.length} characters)';
}

/// The user's answer to the write confirmation: run the text it showed, or not.
final class EditorConfirmationAnswered extends EditorRunEvent {
  const EditorConfirmationAnswered({required this.confirmed});

  final bool confirmed;

  @override
  List<Object?> get props => [confirmed];
}

/// The delay a rate limit asked for has passed, so Run may send again.
final class EditorRateLimitElapsed extends EditorRunEvent {
  const EditorRateLimitElapsed();
}
