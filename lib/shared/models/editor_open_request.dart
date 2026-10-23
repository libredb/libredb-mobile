import 'package:equatable/equatable.dart';

/// A statement any screen hands to the SQL editor: the editor makes [connectionId] the active connection, picks
/// [catalog] as its database when the connection runs statements in a picked one (`catalogSessions`), and puts [text]
/// in the field without running it, asking first when the field holds another text.
///
/// The statement never becomes part of a location: it travels in memory only, as an [EditorOpenDelivery].
class EditorOpenRequest extends Equatable {
  const EditorOpenRequest({required this.connectionId, required this.text, this.catalog});

  final String connectionId;
  final String text;
  final String? catalog;

  @override
  List<Object?> get props => [connectionId, text, catalog];

  /// Prints the length of the text, never the text, which can hold customer data in its literals.
  @override
  String toString() => 'EditorOpenRequest($connectionId, ${text.length} characters, catalog: ${catalog ?? 'none'})';
}

/// One hand-over of an [EditorOpenRequest] to the editor, sent as the go_router `extra` of the SQL tab: the editor
/// takes the request once, so a rebuild of the page never puts the text in the field again.
final class EditorOpenDelivery {
  EditorOpenDelivery(EditorOpenRequest request) : _request = request;

  EditorOpenRequest? _request;

  /// The request, the first time only; null after that.
  EditorOpenRequest? take() {
    final request = _request;
    _request = null;
    return request;
  }

  /// go_router encodes the `extra` of every location it goes to for state restoration. A delivery encodes as null, so
  /// the statement stays in memory and is never handed to the platform; a restored SQL tab opens without it.
  Object? toJson() => null;

  @override
  String toString() => 'EditorOpenDelivery';
}
