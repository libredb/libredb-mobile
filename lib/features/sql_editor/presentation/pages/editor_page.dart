import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_run_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_result_area.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';

/// The SQL editor of [connectionId]: the statement capture note while governance records statements in full, the text
/// field, Run, and the result under them.
///
/// One column at every size, so a rotation rebuilds the same widgets: the text and its selection live in this page's
/// controller and the result in the blocs above the result area, and none of them reloads. The shell's scaffold resizes
/// the column above the keyboard, so the keyboard never covers the result.
///
/// A text the write check flags runs only after the confirmation sheet, for the first run and for each Load more.
class EditorPage extends StatelessWidget {
  const EditorPage({super.key, required this.connectionId});

  final String connectionId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => EditorRunBloc(
      repository: context.read<ISqlEditorRepository>(),
      providerMeta: context.read<IProviderMetaRepository>(),
      schemaChanges: context.read<SchemaChangeNotifier>(),
      connectionId: connectionId,
    ),
    child: const _EditorView(),
  );
}

class _EditorView extends StatefulWidget {
  const _EditorView();

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// The confirmation sheet this page shows, while it is open.
  Route<WriteConfirmation>? _sheet;

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
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run() {
    _focus.unfocus();
    context.read<EditorRunBloc>().add(EditorRunRequested(text: _text.text, role: StudioRoleScope.of(context)));
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
        _text.selection = TextSelection.collapsed(offset: position.clamp(0, _text.text.length));
        _focus.requestFocus();
      case EditorIdle() || EditorRunning() || EditorSucceeded() || EditorStatementFailed() || EditorFailed():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditorRunBloc, EditorRunState>(
      // A failure restored by a cancelled confirmation is no new answer, so the cursor stays where the user put it.
      listenWhen: (previous, current) =>
          current is EditorAwaitingConfirmation ||
          (current is EditorStatementFailed && previous is! EditorAwaitingConfirmation),
      listener: _onStateChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (StatementCaptureScope.recordsInFullOf(context)) const StatementCaptureNote(),
          Flexible(
            flex: 2,
            child: EditorInput(controller: _text, focusNode: _focus),
          ),
          EditorActions(text: _text, onRun: _run),
          const Divider(height: 1),
          Expanded(flex: 3, child: EditorResultArea(confirm: _confirm)),
        ],
      ),
    );
  }
}
