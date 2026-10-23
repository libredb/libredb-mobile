import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
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
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';
import 'package:libredb_mobile/shared/models/editor_open_request.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
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
/// there is opened as an open request ([openEditor]), so an entry of another connection opens that connection's editor.
///
/// An open request for [connectionId] arrives as [openRequest]: its text replaces the field's, after asking when the
/// field holds another text, and never runs; its database becomes the active one once the text is in, on a server-level
/// connection only. A cancelled replace keeps both the text and the database.
///
/// A run refused with `studio.connection_not_available` hands [connectionId] to the active connection's vanish flow, as
/// the Browse pages do, so the SQL tab never keeps a connection Studio no longer offers; nothing is sent again.
///
/// A run keeps background time while it is in flight, and a run that the app's switch to the background interrupted
/// says so on return: Run again for a read, and that the outcome is unknown for anything else.
class EditorPage extends StatelessWidget {
  const EditorPage({super.key, required this.connectionId, this.openRequest});

  final String connectionId;

  final EditorOpenDelivery? openRequest;

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
            lifecycle: context.read<IAppLifecycleSource>(),
            backgroundRunTime: context.read<IBackgroundRunTime>(),
            connectionId: connectionId,
          ),
        ),
        BlocProvider(
          create: (context) => EditorCatalogBloc(
            containers: context.read<IContainersRepository>(),
            providerMeta: context.read<IProviderMetaRepository>(),
            activeCatalog: context.read<ActiveCatalogCubit>(),
            connectionId: connectionId,
            onRequestedNotListed: (requested, used) => _sayCatalogNotListed(messenger, requested, used),
          )..add(const EditorCatalogRequested()),
        ),
        BlocProvider(
          create: (context) =>
              EditorLanguageCubit(providerMeta: context.read<IProviderMetaRepository>(), connectionId: connectionId)
                ..load(),
        ),
        BlocProvider(
          create: (context) => EditorDraftBloc(
            store: context.read<IStatementTextStore>(),
            connectionId: connectionId,
            onLateOutcome: (outcome) => _sayDraftNotKept(messenger, outcome),
          ),
        ),
      ],
      child: _EditorView(connectionId: connectionId, openRequest: openRequest),
    );
  }

  /// Names the database an open request asked for that the server does not list, and the one the editor uses.
  static void _sayCatalogNotListed(ScaffoldMessengerState messenger, String requested, String? used) {
    if (!messenger.mounted) {
      throw StateError('The app\'s ScaffoldMessenger is gone, so a database the server does not list cannot be named');
    }
    final s = S.of(messenger.context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            used == null ? s.editor_catalog_not_listed_none(requested) : s.editor_catalog_not_listed(requested, used),
          ),
        ),
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

  /// Says on the app's messenger that a draft saved as the editor closed, or for the previous account, was not kept.
  static void _sayDraftNotKept(ScaffoldMessengerState messenger, EditorDraftState outcome) {
    if (!messenger.mounted) {
      throw StateError('The app\'s ScaffoldMessenger is gone, so a draft that was not kept cannot be shown');
    }
    final context = messenger.context;
    final s = S.of(context);
    final text = switch (outcome) {
      EditorDraftNotKept() => s.sql_editor_draft_not_kept,
      EditorDraftSaveFailed(:final errorCode) => s.sql_editor_draft_not_saved(errorCode.resolve(context)),
      EditorDraftUnreadable() => AppErrorCode.editorSavedTextUnreadable.resolve(context),
      EditorDraftInitial() ||
      EditorDraftOff() ||
      EditorDraftLoading() ||
      EditorDraftConflict() ||
      EditorDraftRestored() ||
      EditorDraftKept() ||
      EditorDraftReadFailed() => throw ArgumentError.value(outcome, 'outcome', 'not an outcome of a save'),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _EditorView extends StatefulWidget {
  const _EditorView({required this.connectionId, this.openRequest});

  final String connectionId;
  final EditorOpenDelivery? openRequest;

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

  /// The database of the restored draft, made active once the server lists it, and kept with the draft until then and
  /// while the databases cannot be listed.
  String? _restoredCatalog;

  @override
  void initState() {
    super.initState();
    _text.addListener(_tellDraft);
    // The app may be killed in the background, so the draft is saved as it leaves the screen.
    _lifecycle = AppLifecycleListener(
      onHide: () => context.read<EditorDraftBloc>().add(const EditorDraftFlushRequested()),
    );
    _receive(widget.openRequest);
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

  /// The database the draft keeps with its text: the one a Run would send once the databases are listed, and the
  /// restored draft's own until then, so a list that fails or a page left early never saves the draft without it.
  String? get _catalog => switch (context.read<EditorCatalogBloc>().state) {
    final EditorCatalogListed listed => listed.catalogToSend(
      context.read<ActiveCatalogCubit>().catalogOf(widget.connectionId),
    ),
    EditorCatalogNotUsed() => null,
    EditorCatalogChecking() ||
    EditorCatalogMetaFailure() ||
    EditorCatalogLoading() ||
    EditorCatalogFailure() => _restoredCatalog,
  };

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

  /// Asks whether the account's saved draft takes the place of the text typed before Studio named the account; either
  /// answer goes to the draft, which restores the saved one or saves the typed one.
  Future<void> _askConflict(EditorDraftState state) async {
    if (state case EditorDraftConflict(:final draft)) {
      final bloc = context.read<EditorDraftBloc>();
      final restore = await confirmReplaceEditorText(context, current: _text.text, incoming: draft.text);
      if (!mounted) return;
      bloc.add(EditorDraftConflictAnswered(restore: restore));
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
  void didUpdateWidget(_EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.openRequest, oldWidget.openRequest)) _receive(widget.openRequest);
  }

  /// Takes the open request out of [delivery] once the frame is built, since the replace prompt needs this page in the
  /// tree; a delivery taken before has nothing left to hand over, so a rebuild never puts the text in again.
  ///
  /// The request waits for the connection's draft: a draft restored after the request would take its place, so the
  /// request is put in once the draft is read, and asks before it replaces a restored draft that differs.
  void _receive(EditorOpenDelivery? delivery) {
    if (delivery == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final request = delivery.take();
      if (request == null) return;
      final drafts = context.read<EditorDraftBloc>();
      if (!_draftSettled(drafts.state)) {
        await drafts.stream.firstWhere(_draftSettled, orElse: () => drafts.state);
        // The restored draft reaches the field through its listener before this await resumes.
        if (!mounted) return;
      }
      await _putInField(request.text, catalog: request.catalog);
    });
  }

  /// Whether the draft no longer stands to replace the field's text: it was read (or there is none to read), and no
  /// question about a text typed before Studio named the account is open.
  static bool _draftSettled(EditorDraftState state) => switch (state) {
    EditorDraftInitial() || EditorDraftLoading() || EditorDraftConflict() => false,
    EditorDraftOff() ||
    EditorDraftRestored() ||
    EditorDraftKept() ||
    EditorDraftNotKept() ||
    EditorDraftSaveFailed() ||
    EditorDraftUnreadable() ||
    EditorDraftReadFailed() => true,
  };

  /// Puts [text] in the field, after asking when it would replace another text, then makes [catalog] the active
  /// database; nothing runs, and a cancel changes neither.
  Future<void> _putInField(String text, {String? catalog}) async {
    if (!await confirmReplaceEditorText(context, current: _text.text, incoming: text)) return;
    if (!mounted) return;
    // The text of a restored draft is gone, and so is its claim on the database.
    _restoredCatalog = null;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (catalog != null) context.read<EditorCatalogBloc>().add(EditorCatalogOpenRequested(catalog));
  }

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

  /// Opens the account's History over this editor and opens the tapped entry as an open request, on the entry's own
  /// connection; nothing runs.
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
    if (!mounted || entry == null || text == null) return;
    openEditor(context, EditorOpenRequest(connectionId: entry.connectionId, text: text));
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
          EditorFailed() ||
          EditorInterrupted():
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
        BlocListener<EditorRunBloc, EditorRunState>(
          listenWhen: (previous, current) =>
              current is EditorFailed && current.error.code == AppErrorCode.studioConnectionNotAvailable.key,
          listener: (context, state) => context.read<ActiveConnectionCubit>().reportUnavailable(widget.connectionId),
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
        BlocListener<EditorDraftBloc, EditorDraftState>(
          listenWhen: (previous, current) => current is EditorDraftConflict,
          listener: (context, state) => _askConflict(state),
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
              // Read only while the account's draft is read; a text typed before Studio named the account is asked about.
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
          Expanded(
            flex: 3,
            child: EditorResultArea(confirm: _confirm, onRunAgain: _run),
          ),
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
