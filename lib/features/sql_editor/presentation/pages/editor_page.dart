import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_catalog_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_draft_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_language_cubit.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/domain/editor_language.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_accessory_row.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_catalog_chip.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_draft_notice.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_language_label.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_result_area.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/highlighting_text_controller.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/replace_text_prompt.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/statement_history_sheet.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';
import 'package:libredb_mobile/shared/widgets/studio_subject_scope.dart';

/// The SQL editor of [connectionId]: the statement capture note while governance records statements in full, the
/// engine's language, the text field coloured by it, what the draft store says, Run (Cancel while a statement runs),
/// the result, and, while the field has focus, the accessory row above the keyboard.
///
/// One column at every size, so a rotation rebuilds the same widgets: the text, its selection, its scroll position and
/// its undo history live in this page's controllers and the result in the blocs above the result area, and none of
/// them reloads. The shell's scaffold resizes the column above the keyboard, so neither the keyboard nor the accessory
/// row ever covers the result.
///
/// The text is the connection's draft for the signed-in account (`EditorDraftBloc`), kept with the database it is
/// typed for: restored when the editor opens, with its database made active again while the server still lists it,
/// and saved after a pause in typing, when the app goes to the background and when the editor closes, which leaving
/// the tab, switching the connection and a vanished connection all do.
///
/// Run sends the text's non-blank selection when there is one, else the whole text. A text the write check flags runs
/// only after the confirmation sheet, for the first run and for each Load more.
///
/// On a server-level connection the database chip sits above the text, and Run sends the active database; switching
/// database keeps the text.
///
/// Each run that reached Studio is added to the account's history on the phone, which History opens; an entry tapped
/// there replaces the text, after asking when the text differs, and never runs.
class EditorPage extends StatelessWidget {
  const EditorPage({super.key, required this.connectionId});

  final String connectionId;

  @override
  Widget build(BuildContext context) {
    // The app's messenger, which outlives this page, so a history write refused after the editor closed is still said
    // on whatever page the user is on.
    final messenger = ScaffoldMessenger.of(context);
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => EditorRunBloc(
            repository: context.read<ISqlEditorRepository>(),
            providerMeta: context.read<IProviderMetaRepository>(),
            schemaChanges: context.read<SchemaChangeNotifier>(),
            history: context.read<IStatementHistoryRepository>(),
            onHistoryNotKept: (code) => _sayHistoryNotKept(messenger, code),
            connectionId: connectionId,
          ),
        ),
        BlocProvider(
          create: (context) => EditorCatalogBloc(
            containers: context.read<IContainersRepository>(),
            providerMeta: context.read<IProviderMetaRepository>(),
            activeCatalog: context.read<ActiveCatalogCubit>(),
            connectionId: connectionId,
          )..add(const EditorCatalogRequested()),
        ),
        BlocProvider(
          create: (context) =>
              EditorLanguageCubit(providerMeta: context.read<IProviderMetaRepository>(), connectionId: connectionId)
                ..load(),
        ),
        BlocProvider(
          create: (context) => EditorDraftBloc(store: context.read<IStatementTextStore>(), connectionId: connectionId),
        ),
      ],
      child: _EditorView(connectionId: connectionId),
    );
  }

  static void _sayHistoryNotKept(ScaffoldMessengerState messenger, AppErrorCode code) {
    if (!messenger.mounted) {
      throw StateError('The app\'s ScaffoldMessenger is gone, so a refused history write cannot be shown');
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(code.resolve(messenger.context))));
  }
}

class _EditorView extends StatefulWidget {
  const _EditorView({required this.connectionId});

  final String connectionId;

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView> {
  final _text = HighlightingTextController();
  final _focus = FocusNode();
  final _undo = UndoHistoryController();
  final _scroll = ScrollController();
  late final AppLifecycleListener _lifecycle;

  /// The text and the database last told to the draft, so a move of the cursor or a change of colouring alone tells
  /// it nothing.
  (String, String?) _told = ('', null);

  /// The account the draft is kept for, as the subject hash last told to the draft.
  String? _subject;
  bool _subjectTold = false;

  /// The database of the restored draft, made active once the server lists it.
  String? _restoredCatalog;

  @override
  void initState() {
    super.initState();
    _text.addListener(_tellDraft);
    // The app may be killed in the background, so the draft is saved as it leaves the screen.
    _lifecycle = AppLifecycleListener(
      onHide: () => context.read<EditorDraftBloc>().add(const EditorDraftFlushRequested()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final subject = StudioSubjectScope.of(context);
    if (!_subjectTold || subject != _subject) {
      _subjectTold = true;
      _subject = subject;
      context.read<EditorDraftBloc>().add(EditorDraftSubjectChanged(subject));
    }
  }

  /// The database a Run would send now, which the draft keeps with its text.
  String? get _catalog => context.read<EditorCatalogBloc>().state.catalogToSend(
    context.read<ActiveCatalogCubit>().catalogOf(widget.connectionId),
  );

  /// Tells the draft the text and the database, when either changed.
  void _tellDraft() {
    final told = (_text.text, _catalog);
    if (told == _told) return;
    _told = told;
    context.read<EditorDraftBloc>().add(EditorDraftTextChanged(told.$1, catalog: told.$2));
  }

  /// Shows the restored draft in the field, with the cursor at its end, and makes its database active again; the
  /// field tells the draft its text as for any change, which the draft does not save again.
  void _restore(EditorDraftState state) {
    if (state case EditorDraftRestored(:final draft)) {
      _restoredCatalog = draft.catalog;
      _applyRestoredCatalog();
      _text.value = TextEditingValue(
        text: draft.text,
        selection: TextSelection.collapsed(offset: draft.text.length),
      );
    }
  }

  /// Makes the restored draft's database active once the server's databases are listed and still hold it; a database
  /// the server no longer lists leaves the one the editor chose.
  void _applyRestoredCatalog() {
    final catalog = _restoredCatalog;
    if (catalog == null) return;
    if (context.read<EditorCatalogBloc>().state case EditorCatalogListed(:final catalogs)) {
      _restoredCatalog = null;
      if (catalogs.contains(catalog)) context.read<ActiveCatalogCubit>().choose(widget.connectionId, catalog);
    }
  }

  /// The confirmation sheet this page shows, while it is open.
  Route<WriteConfirmation>? _sheet;

  /// The History sheet this page shows, while it is open.
  Route<StatementHistoryEntry>? _historySheet;

  /// Where the text of the last Run starts in the field: the selection's start, or 0 for the whole text, so a database
  /// error's position in the text that ran points at the right place in the field.
  int _runStart = 0;

  @override
  void dispose() {
    // The sheet sits on the root navigator, above the shell, so a deep link or a session end that disposes this page
    // would leave it open; it answers cancelled instead and never outlives the page that asked. The root navigator is
    // still updating its pages while this page is disposed, so the sheet is removed once that frame has finished.
    if (_sheet case final sheet?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheet.isActive) sheet.navigator?.removeRoute(sheet, WriteConfirmation.cancelled);
      });
    }
    _sheet = null;
    // The History sheet sits there too, and closes the same way.
    if (_historySheet case final sheet?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheet.isActive) sheet.navigator?.removeRoute(sheet);
      });
    }
    _historySheet = null;
    _lifecycle.dispose();
    _text.dispose();
    _focus.dispose();
    _undo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _run() {
    final value = _text.value;
    final selected = EditorActions.selectedText(value);
    final isSelection = selected.trim().isNotEmpty;
    _runStart = isSelection ? value.selection.start : 0;
    _focus.unfocus();
    final catalog = context.read<EditorCatalogBloc>().state.catalogToSend(
      context.read<ActiveCatalogCubit>().catalogOf(widget.connectionId),
    );
    final subject = StudioSubjectScope.of(context);
    final connection = context.read<ActiveConnectionCubit>().state.connection;
    context.read<EditorRunBloc>().add(
      EditorRunRequested(
        text: isSelection ? selected : value.text,
        role: StudioRoleScope.of(context),
        catalog: catalog,
        isSelection: isSelection,
        history: subject == null || connection == null
            ? null
            : EditorHistoryTarget(subjectHash: subject, connectionName: connection.name),
      ),
    );
  }

  /// Opens the account's History over this editor and puts the tapped entry's text in the field, after asking when it
  /// would replace another text; nothing runs.
  Future<void> _openHistory(String subjectHash) async {
    final connectionId = context.read<EditorRunBloc>().connectionId;
    final entry = await showStatementHistorySheet(
      context,
      subjectHash: subjectHash,
      activeConnectionId: connectionId,
      onRoute: (route) => _historySheet = route,
    );
    _historySheet = null;
    final text = entry?.text;
    if (!mounted || text == null) return;
    if (!await confirmReplaceEditorText(context, current: _text.text, incoming: text)) return;
    if (!mounted) return;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Shows the confirmation of [statement] on the open connection and answers whether the user confirmed it; a
  /// connection that closed meanwhile, or a page disposed while the sheet was open, answers no.
  Future<bool> _confirm(EditorStatement statement) async {
    final connection = context.read<ActiveConnectionCubit>().state.connection;
    final asks = statement.asks;
    if (connection == null || asks == null) return false;
    final answer = await showWriteConfirmationSheet(
      context,
      connection: connection,
      text: statement.text,
      answer: asks,
      onRoute: (route) => _sheet = route,
    );
    _sheet = null;
    // A page disposed while the sheet was open has no run left to send for, a page of Load more included.
    if (!mounted) return false;
    return answer == WriteConfirmation.confirmed;
  }

  Future<void> _onStateChanged(BuildContext context, EditorRunState state) async {
    switch (state) {
      case EditorAwaitingConfirmation(:final statement):
        final bloc = context.read<EditorRunBloc>();
        final confirmed = await _confirm(statement);
        // A session that ends while the sheet is open (an inactivity sign-out, or a Studio session that ended) takes
        // the router to the login page and disposes this page with its run, so there is nothing left to answer.
        if (!mounted) return;
        bloc.add(EditorConfirmationAnswered(confirmed: confirmed));
      case EditorStatementFailed(:final position?):
        _text.selection = TextSelection.collapsed(offset: (_runStart + position).clamp(0, _text.text.length));
        _focus.requestFocus();
      case EditorIdle() ||
          EditorRunning() ||
          EditorCancelling() ||
          EditorCancelled() ||
          EditorSucceeded() ||
          EditorScriptAnswered() ||
          EditorStatementFailed() ||
          EditorFailed():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<EditorRunBloc, EditorRunState>(
          // A failure restored by a cancelled confirmation is no new answer, so the cursor stays where the user put it.
          listenWhen: (previous, current) =>
              current is EditorAwaitingConfirmation ||
              (current is EditorStatementFailed && previous is! EditorAwaitingConfirmation),
          listener: _onStateChanged,
        ),
        BlocListener<EditorLanguageCubit, EditorLanguageState>(
          listener: (context, state) => _text.highlighting = switch (state) {
            EditorLanguageKnown(:final language) => language.highlighting,
            EditorLanguageLoading() || EditorLanguageUnknown() => EditorHighlighting.plain,
          },
        ),
        BlocListener<EditorDraftBloc, EditorDraftState>(
          listenWhen: (previous, current) => current is EditorDraftRestored,
          listener: (context, state) => _restore(state),
        ),
        BlocListener<EditorCatalogBloc, EditorCatalogState>(
          listener: (context, state) {
            _applyRestoredCatalog();
            _tellDraft();
          },
        ),
        BlocListener<ActiveCatalogCubit, ActiveCatalogState>(listener: (context, state) => _tellDraft()),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (StatementCaptureScope.recordsInFullOf(context)) const StatementCaptureNote(),
          EditorCatalogChip(connectionId: widget.connectionId),
          const EditorLanguageLabel(),
          Flexible(
            flex: 2,
            child: BlocSelector<EditorDraftBloc, EditorDraftState, bool>(
              selector: (state) => state is EditorDraftLoading,
              builder: (context, loading) => EditorInput(
                controller: _text,
                focusNode: _focus,
                undoController: _undo,
                scrollController: _scroll,
                readOnly: loading,
              ),
            ),
          ),
          const EditorDraftNotice(),
          EditorActions(
            text: _text,
            onRun: _run,
            onCancel: () => context.read<EditorRunBloc>().add(const EditorCancelRequested()),
            onStopWaiting: () => context.read<EditorRunBloc>().add(const EditorCancelRequested(stopWaiting: true)),
            withheld: context.watch<EditorCatalogBloc>().state.withholdsRun(
              context.select<ActiveCatalogCubit, String?>((cubit) => cubit.catalogOf(widget.connectionId)),
            ),
            onHistory: switch (StudioSubjectScope.of(context)) {
              final subject? => () => _openHistory(subject),
              null => null,
            },
          ),
          const Divider(height: 1),
          Expanded(flex: 3, child: EditorResultArea(confirm: _confirm)),
          ListenableBuilder(
            listenable: _focus,
            builder: (context, _) => _focus.hasFocus
                ? EditorAccessoryRow(controller: _text, undoController: _undo)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
