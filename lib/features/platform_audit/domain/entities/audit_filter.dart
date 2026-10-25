import 'package:equatable/equatable.dart';

/// The filters of a read of LibreDB Platform's audit log (`GET /api/v1/audit`, libredb-platform
/// `src/shared/lib/bridge/query-events.ts`), each optional.
///
/// Every string value is trimmed and an empty one is unset, since Platform ignores an empty filter and the app never
/// sends one. [search] is cut to its first [maxSearchLength] UTF-16 code units, Platform's limit, without splitting a
/// surrogate pair.
///
/// A filter value can name a person or quote a statement, so the text of a filter names only the set filters.
final class AuditFilter extends Equatable {
  const AuditFilter({
    this._subject,
    this._connectionId,
    this._source,
    this._statementType,
    this._status,
    this.from,
    this.to,
    this._search,
  });

  /// Platform's limit on [search], in UTF-16 code units, the unit of JavaScript's and Dart's `String.length`.
  static const maxSearchLength = 200;

  final String? _subject;
  final String? _connectionId;
  final String? _source;
  final String? _statementType;
  final String? _status;
  final String? _search;

  /// The Keycloak `sub` of a user, matched exactly.
  String? get subject => _clean(_subject);

  /// A Platform connection id, matched exactly.
  String? get connectionId => _clean(_connectionId);

  /// What sent the statement, such as `studio`.
  String? get source => _clean(_source);

  /// `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `DDL` or `OTHER`.
  String? get statementType => _clean(_statementType);

  /// `success`, `error`, `cancelled` or `refused`.
  String? get status => _clean(_status);

  /// The inclusive lower bound on an event's start.
  final DateTime? from;

  /// The inclusive upper bound on an event's start.
  final DateTime? to;

  /// Text matched literally in the statement, ignoring case; an event without a recorded statement never matches.
  String? get search {
    final text = _clean(_search);
    if (text == null || text.length <= maxSearchLength) return text;
    // A high surrogate as the last unit kept would leave half a character.
    final end = _isHighSurrogate(text.codeUnitAt(maxSearchLength - 1)) ? maxSearchLength - 1 : maxSearchLength;
    return text.substring(0, end);
  }

  /// The Platform names of the set filters, in Platform's order.
  List<String> get setFilterNames => [
    if (subject != null) 'subject',
    if (connectionId != null) 'connectionId',
    if (source != null) 'source',
    if (statementType != null) 'statementType',
    if (status != null) 'status',
    if (from != null) 'from',
    if (to != null) 'to',
    if (search != null) 'search',
  ];

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  @override
  List<Object?> get props => [subject, connectionId, source, statementType, status, from, to, search];

  /// Only the names of the set filters, never a value: this text can reach a log.
  @override
  String toString() => 'AuditFilter(${setFilterNames.join(', ')})';
}
