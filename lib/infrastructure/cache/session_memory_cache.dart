import 'package:clock/clock.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/storage/session_generation.dart';

/// Successful answers of the signed-in session, kept in memory only and never written to disk.
///
/// An answer is stored only while the session it was sent under has not ended ([SessionGeneration]) and no
/// invalidation covering it ran since it was sent, so an answer still on its way when the user signs out, or when a
/// statement drops the object, never refills the cache. Callers asking for a key while its request is in flight share
/// that request, unless the session ended or the key was invalidated since it was sent. A failure is never stored, and
/// leaves the entry that was there.
class SessionMemoryCache<K, V> {
  /// [ttl] is how long an entry is served, checked on read; null keeps it for the whole session. [now] reads the time,
  /// `package:clock` by default.
  SessionMemoryCache({this.ttl, DateTime Function()? now}) : _now = now ?? (() => clock.now());

  final Duration? ttl;
  final DateTime Function() _now;

  final _entries = <K, _Entry<V>>{};
  final _inFlight = <K, _Request<V>>{};

  /// How many entries are kept, served or not.
  int get length => _entries.length;

  /// The stored answer for [key] while it is fresh, else the answer of [send], which is stored when it succeeds.
  ///
  /// [refresh] skips the stored answer and any request in flight, and replaces the entry with the new answer; the
  /// request it overtakes still answers its callers but is not stored.
  Future<Result<V>> read(K key, Future<Result<V>> Function() send, {bool refresh = false}) {
    if (!refresh) {
      final entry = _entries[key];
      if (entry != null) {
        if (_isServed(entry)) return Future.value(Success(entry.value));
        if (SessionGeneration.hasEnded(entry.generation)) _entries.remove(key);
      }
      final request = _inFlight[key];
      if (request != null && !SessionGeneration.hasEnded(request.generation)) return request.answer;
    }
    _inFlight.remove(key)?.dropped = true;
    final request = _Request<V>(SessionGeneration.current);
    _inFlight[key] = request;
    request.answer = _send(key, request, send);
    return request.answer;
  }

  Future<Result<V>> _send(K key, _Request<V> request, Future<Result<V>> Function() send) async {
    try {
      final result = await send();
      if (result case Success(:final data) when !request.dropped && !SessionGeneration.hasEnded(request.generation)) {
        _entries[key] = _Entry(data, storedAt: _now(), generation: request.generation);
      }
      return result;
    } finally {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    }
  }

  /// Drops each entry whose key matches [test], and keeps the answer of each matching request in flight from being
  /// stored or shared.
  void invalidateWhere(bool Function(K key) test) {
    _entries.removeWhere((key, _) => test(key));
    _inFlight.removeWhere((key, request) {
      if (!test(key)) return false;
      request.dropped = true;
      return true;
    });
  }

  /// Drops each entry past its time to live, or stored under a session that has ended.
  void evictExpired() => _entries.removeWhere((_, entry) => !_isServed(entry));

  /// Drops every entry and every request in flight, as when the session ends.
  void clear() => invalidateWhere((_) => true);

  bool _isServed(_Entry<V> entry) {
    if (SessionGeneration.hasEnded(entry.generation)) return false;
    final ttl = this.ttl;
    return ttl == null || _now().difference(entry.storedAt) < ttl;
  }
}

class _Entry<V> {
  _Entry(this.value, {required this.storedAt, required this.generation});

  final V value;
  final DateTime storedAt;
  final int generation;
}

class _Request<V> {
  _Request(this.generation);

  /// The session generation the request was sent under.
  final int generation;
  late final Future<Result<V>> answer;

  /// Set when an invalidation, the session end or a refresh overtook the request, so its answer is not stored.
  bool dropped = false;
}
