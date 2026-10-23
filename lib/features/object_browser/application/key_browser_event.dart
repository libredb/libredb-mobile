part of 'key_browser_bloc.dart';

sealed class KeyBrowserEvent extends Equatable {
  const KeyBrowserEvent();

  @override
  List<Object?> get props => const [];
}

/// An event that reads pages. These are droppable: one sent while a page is in flight is ignored.
sealed class KeyBrowserPageEvent extends KeyBrowserEvent {
  const KeyBrowserPageEvent();
}

/// Reads the engine's walk and its first page, on open and on a retry after nothing could be read.
final class KeyBrowserStarted extends KeyBrowserPageEvent {
  const KeyBrowserStarted();
}

/// Starts the walk again from its first page with the pattern the user typed.
final class KeyBrowserPatternSubmitted extends KeyBrowserPageEvent {
  const KeyBrowserPatternSubmitted(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Reads the next page, and after a failed page reads it again from the same cursor.
final class KeyBrowserMoreRequested extends KeyBrowserPageEvent {
  const KeyBrowserMoreRequested();
}

/// Reads page after page until the walk ends, the screen holds [KeyBrowserBloc.heldKeyLimit] keys, or Stop.
final class KeyBrowserAllRequested extends KeyBrowserPageEvent {
  const KeyBrowserAllRequested();
}

/// Stops a Load all after the page in flight.
final class KeyBrowserStopped extends KeyBrowserEvent {
  const KeyBrowserStopped();
}
