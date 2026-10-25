part of 'directory_picker_bloc.dart';

sealed class DirectoryPickerEvent extends Equatable {
  const DirectoryPickerEvent();

  @override
  List<Object?> get props => const [];
}

/// The picker opened: the first page of every user is asked for at once.
final class DirectoryPickerOpened extends DirectoryPickerEvent {
  const DirectoryPickerOpened();
}

/// The search field now holds [text], as typed.
final class DirectoryPickerQueryChanged extends DirectoryPickerEvent {
  const DirectoryPickerQueryChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];

  /// Not the text: it can name a user, and this event can reach a log.
  @override
  String toString() => 'DirectoryPickerQueryChanged(length: ${text.length})';
}

/// Retry after the first page failed: the same query is sent again.
final class DirectoryPickerRetryRequested extends DirectoryPickerEvent {
  const DirectoryPickerRetryRequested();
}

/// The next page of the query on screen, also after the last one failed.
final class DirectoryPickerLoadMoreRequested extends DirectoryPickerEvent {
  const DirectoryPickerLoadMoreRequested();
}

/// Sends the first page of [query]; [generation] tells a late answer apart.
final class _DirectoryPickerSearchSent extends DirectoryPickerEvent {
  const _DirectoryPickerSearchSent(this.query, this.generation);

  final String query;
  final int generation;

  @override
  List<Object?> get props => [query, generation];

  @override
  String toString() => '_DirectoryPickerSearchSent(length: ${query.length}, generation: $generation)';
}
