import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/redis_key_read_generator.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/query_id.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'key_value_event.dart';
part 'key_value_state.dart';

/// The value of the Redis key [keyName] of [connectionId], walked in [container]: the read Studio's key browser writes
/// for the [type] its page read ([RedisKeyReadGenerator]), else `TYPE <key>`, run through [IStatementRepository] with
/// a fresh run id and, when [container]'s first segment is all digits, that numbered database.
///
/// The answer is masked at once with the policy of the role the request carries and the engine's exempt column, so the
/// bloc never holds a clear row. A read runs only when the page asks, on open, a pull, a retry or 'Read value', never
/// again by itself, and a request while one runs is dropped. Neither the key's value, the command nor a database error
/// text is logged.
class KeyValueBloc extends Bloc<KeyValueEvent, KeyValueState> {
  KeyValueBloc({
    required this._statements,
    required this._providerMeta,
    required this.connectionId,
    required this.container,
    required this.keyName,
    this._type,
    this._generator = const RedisKeyReadGenerator(),
    this._newRunId = newQueryId,
  }) : super(const KeyValueLoading()) {
    on<KeyValueEvent>(_onRead, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('KeyValueBloc');
  static final _digits = RegExp(r'^\d+$');

  /// The answers of Redis's provider for a key that does not exist, a nil reply and an empty list, each one row with
  /// `rowCount: 0` (`formatResult`, `src/lib/db/providers/keyvalue/redis.ts:1638`, `:1644`).
  static const _vanishedMarkers = {'(nil)', '(empty list)'};

  final IStatementRepository _statements;
  final IProviderMetaRepository _providerMeta;
  final RedisKeyReadGenerator _generator;
  final String Function() _newRunId;

  /// The connection, from the page's route.
  final String connectionId;

  /// The container the key was walked in, from the page's route.
  final List<String> container;

  /// The key, whole, from the page's route.
  final String keyName;

  /// The type the page named, or the one the user chose to read after a `TYPE` answer.
  String? _type;

  /// The value answers so far, which tells one result on screen from the next.
  int _runs = 0;

  /// The numbered database the key was walked in: the container's first segment when it is all digits, else null.
  /// Throws a [FormatException] for digits too many for an int, which name no database the app can send.
  int? get _database {
    if (container.isEmpty || !_digits.hasMatch(container.first)) return null;
    return int.parse(container.first);
  }

  Future<void> _onRead(KeyValueEvent event, Emitter<KeyValueState> emit) async {
    final StudioRole? role;
    switch (event) {
      case KeyValueRequested():
        role = event.role;
      case KeyValueTypedReadRequested():
        role = event.role;
        _type = event.type;
    }
    final onScreen = switch (state) {
      final KeyValueShown shown => shown,
      KeyValueFailure(:final previous) => previous,
      KeyValueLoading() || KeyValueUnavailable() => null,
    };
    if (onScreen != null) {
      emit(onScreen.copyWith(isRefreshing: true));
    } else if (state is! KeyValueLoading) {
      emit(const KeyValueLoading());
    }

    final ProviderMeta meta;
    switch (await _providerMeta.providerMeta(connectionId)) {
      case Failure(:final error):
        if (emit.isDone) return;
        _fail(emit, error, onScreen: onScreen);
        return;
      case Success(:final data):
        meta = data;
    }
    if (emit.isDone) return;
    // Only Redis is read this way; an engine with a key-browser kind opens the key's source, and any other runs nothing.
    if (meta.queryDialect != 'redis' || meta.objectKinds.any((kind) => kind.keyBrowserOnly)) {
      _log.warn('the engine reads no key value through a typed read');
      emit(const KeyValueUnavailable());
      return;
    }

    final int? database;
    try {
      database = _database;
    } on FormatException {
      // Sending none would read the session's default database instead of the one the key was walked in.
      _log.warn('the walked database number is out of range');
      _fail(emit, const ValidationError('The walked database number is out of range'), onScreen: onScreen);
      return;
    }
    final read = _generator.read(keyName, _type);
    final result = await _statements.run(connectionId, read.statement, queryId: _newRunId(), database: database);
    if (emit.isDone) return;
    switch (result) {
      case Failure(:final error):
        _fail(emit, error, onScreen: onScreen);
      case Success(:final data) when _vanished(data):
        emit(KeyValueVanished(loadedAt: clock.now()));
      case Success(:final data) when read.type == null:
        _answerType(emit, data, onScreen: onScreen);
      case Success(:final data):
        final policy = MaskingPolicy.forRole(role, exempt: meta.maskingExemptColumns);
        emit(
          KeyValueLoaded(
            read: read,
            masked: maskResult(data, policy),
            policy: policy,
            run: ++_runs,
            loadedAt: clock.now(),
          ),
        );
    }
  }

  static bool _vanished(QueryResult result) =>
      result.rowCount == 0 &&
      result.rows.length == 1 &&
      result.rows.single.length == 1 &&
      _vanishedMarkers.contains(result.rows.single['result']);

  void _answerType(Emitter<KeyValueState> emit, QueryResult result, {required KeyValueShown? onScreen}) {
    final type = result.rows.length == 1 ? result.rows.single['result'] : null;
    if (type is! String) {
      _fail(
        emit,
        ServerError('TYPE answered no single text result', code: AppErrorCode.studioUnreadableAnswer.key),
        onScreen: onScreen,
      );
      return;
    }
    if (type.trim().toLowerCase() == 'none') {
      emit(KeyValueVanished(loadedAt: clock.now()));
      return;
    }
    emit(KeyValueTypeAnswered(type: type, readable: RedisKeyReadGenerator.keyType(type), loadedAt: clock.now()));
  }

  void _fail(Emitter<KeyValueState> emit, AppError error, {required KeyValueShown? onScreen}) {
    _log.warn('key not read: {}', [error.code ?? error.runtimeType]);
    // A request the offline device never sent says nothing new, so the answer on screen stays, marked stale by the page.
    if (onScreen != null && error.code == AppErrorCode.networkOffline.key) {
      emit(onScreen.copyWith(isRefreshing: false));
      return;
    }
    emit(KeyValueFailure(error: error, previous: onScreen?.copyWith(isRefreshing: false)));
  }
}
