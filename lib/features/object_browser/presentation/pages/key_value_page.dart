import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/key_value_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/redis_key_read_generator.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_database_words.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_refresh.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/key_browser_list.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/utils/cell_values.dart';
import 'package:libredb_mobile/shared/widgets/cells/detail_cell.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/result_view/row_detail_sheet.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';

/// The value of the Redis key [keyName] of [connectionId], walked in [container], read for the [type] its key browser
/// page read: the key as the heading, a string or JSON document as its text, pretty-printed when it is a JSON object
/// or array, and every other type in the result view, masked as Studio's grid masks it.
///
/// A key with no type shows Studio's `TYPE` answer and offers 'Read value' for one of the seven types; nothing runs a
/// second statement by itself, and a read runs again only on the user's pull or retry. The page is read-only; a copy
/// goes through `SensitiveClipboard`.
class KeyValuePage extends StatelessWidget {
  const KeyValuePage({
    super.key,
    required this.connectionId,
    required this.container,
    required this.keyName,
    this.type,
  });

  final String connectionId;
  final List<String> container;
  final String keyName;
  final String? type;

  @override
  Widget build(BuildContext context) {
    final role = StudioRoleScope.of(context);
    return BlocProvider(
      create: (context) => KeyValueBloc(
        statements: context.read<IStatementRepository>(),
        providerMeta: context.read<IProviderMetaRepository>(),
        connectionId: connectionId,
        container: container,
        keyName: keyName,
        type: type,
      )..add(KeyValueRequested(role: role)),
      child: _KeyValueView(page: this),
    );
  }
}

class _KeyValueView extends StatelessWidget {
  const _KeyValueView({required this.page});

  final KeyValuePage page;

  /// The field Redis's provider answers a string, a JSON document and a `TYPE` in.
  static const _resultField = 'result';

  /// Reads the key again, for the role Studio names now.
  void _run(BuildContext context) =>
      context.read<KeyValueBloc>().add(KeyValueRequested(role: StudioRoleScope.of(context)));

  Future<void> _refresh(BuildContext context) => refreshBrowseUnlessOffline(context, () async {
    final bloc = context.read<KeyValueBloc>();
    // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        KeyValueShown(:final isRefreshing) => !isRefreshing,
        KeyValueFailure() || KeyValueUnavailable() => true,
        KeyValueLoading() => false,
      },
      orElse: () => bloc.state,
    );
    _run(context);
    await done;
  });

  /// Whether [loaded] is one text value: a string or a JSON document, answered as Redis's provider answers one.
  static bool _isText(KeyValueLoaded loaded) {
    final result = loaded.masked.result;
    return RedisKeyReadGenerator.textTypes.contains(loaded.read.type) &&
        result.fields.length == 1 &&
        result.fields.single == _resultField &&
        result.rows.length == 1;
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<KeyValueBloc, KeyValueState>(
    builder: (context, state) {
      final shown = switch (state) {
        final KeyValueShown shown => shown,
        KeyValueFailure(:final previous) => previous,
        KeyValueLoading() || KeyValueUnavailable() => null,
      };
      final error = switch (state) {
        KeyValueFailure(:final error) => error,
        _ => null,
      };
      final text = shown is KeyValueLoaded && _isText(shown) ? shown : null;
      final type = switch (shown) {
        KeyValueLoaded(:final read) => read.type,
        _ => page.type,
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shown != null) OfflineStaleMarker(loadedAt: shown.loadedAt),
          if (error != null) ...[
            BrowseFailureView(connectionId: page.connectionId, error: error, onRetry: () => _run(context)),
            if (browseDatabaseWordsOf(error) case final words?) BrowseDatabaseWords(words),
          ],
          BrowseHeading(
            title: page.keyName,
            overline: S.of(context).keys_value_overline,
            actions: [
              if (type != null && type.isNotEmpty) KeyTypeChip(type: type),
              if (text != null)
                IconButton(
                  key: const ValueKey('key-value-copy'),
                  tooltip: S.of(context).result_copy_value,
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copy(context, _copyText(text)),
                ),
            ],
          ),
          Expanded(child: _body(context, state, shown, text)),
        ],
      );
    },
  );

  static void _copy(BuildContext context, String text) =>
      copyResultText(ScaffoldMessenger.of(context), S.of(context), text);

  /// What Copy value writes: the mask of a masked value, else the value's copy form, the pretty JSON of a document.
  static String _copyText(KeyValueLoaded loaded) =>
      fieldCopyText(loaded.masked.result, loaded.masked.maskedColumns, 0, _resultField);

  Widget _body(BuildContext context, KeyValueState state, KeyValueShown? shown, KeyValueLoaded? text) {
    if (shown == null) {
      return switch (state) {
        KeyValueUnavailable() => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(S.of(context).keys_value_unavailable),
        ),
        KeyValueFailure() => RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(physics: const AlwaysScrollableScrollPhysics()),
        ),
        KeyValueLoading() || KeyValueShown() => const Center(child: CircularProgressIndicator()),
      };
    }
    if (shown is KeyValueLoaded && text == null) {
      return RefreshIndicator(
        onRefresh: () => _refresh(context),
        // A short result still pulls to refresh.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(physics: const AlwaysScrollableScrollPhysics()),
          child: BlocProvider(
            // Each read is a result of its own, masked with the policy of its own read.
            key: ValueKey(shown.run),
            create: (_) => ResultViewBloc(masked: shown.masked, policy: shown.policy),
            child: const ResultView(),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          switch (shown) {
            KeyValueLoaded() => _textValue(context, text!),
            KeyValueTypeAnswered() => _typeAnswer(context, shown),
            KeyValueVanished() => Text(S.of(context).keys_value_vanished, key: const ValueKey('key-value-vanished')),
          },
        ],
      ),
    );
  }

  Widget _textValue(BuildContext context, KeyValueLoaded loaded) {
    final result = loaded.masked.result;
    final row = result.rows.single;
    final cell = isMaskedField(row, _resultField, loaded.masked.maskedColumns)
        ? ScalarCell(row[_resultField]! as String)
        : classifyCell(row[_resultField], isAbsent: !row.containsKey(_resultField));
    return DetailCell(
      key: const ValueKey('key-value-text'),
      cell: cell,
      onCopy: (selected) => _copy(context, selected),
    );
  }

  Widget _typeAnswer(BuildContext context, KeyValueTypeAnswered answer) {
    final s = S.of(context);
    final readable = answer.readable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: [
        Text(s.keys_value_type(answer.type), key: const ValueKey('key-value-type')),
        if (readable == null)
          Text(s.keys_value_no_read)
        else
          OnlineOnlyAction(
            builder: (context, online) => FilledButton.tonal(
              onPressed: online && !answer.isRefreshing
                  ? () => context.read<KeyValueBloc>().add(
                      KeyValueTypedReadRequested(role: StudioRoleScope.of(context), type: readable),
                    )
                  : null,
              child: Text(s.keys_value_read),
            ),
          ),
      ],
    );
  }
}
