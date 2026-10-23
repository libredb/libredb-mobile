import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/pages/editor_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/editor_open_request.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';

/// The root of the SQL tab, which follows the active connection as the Browse tab does: the editor of the open
/// connection, built afresh when another one opens, or, without an open connection, the way to pick one first.
///
/// An open request ([openEditor]) arrives as [delivery]: its connection opens from the managed list when another one is
/// active, and its editor takes the text and the database. A connection the list no longer holds opens nothing, and
/// the page says so.
class SqlPage extends StatefulWidget {
  const SqlPage({super.key, this.delivery});

  final EditorOpenDelivery? delivery;

  @override
  State<SqlPage> createState() => _SqlPageState();
}

class _SqlPageState extends State<SqlPage> {
  /// The request for the editor of its connection, which that editor takes once.
  ({String connectionId, EditorOpenDelivery delivery})? _forEditor;

  @override
  void initState() {
    super.initState();
    _receive(widget.delivery);
  }

  @override
  void didUpdateWidget(SqlPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.delivery, oldWidget.delivery)) _receive(widget.delivery);
  }

  /// Takes the request out of [delivery] once the frame is built, since the message and the switch need the page's
  /// context; a delivery taken before, as by a rebuild of the same location, has nothing left to hand over.
  void _receive(EditorOpenDelivery? delivery) {
    if (delivery == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (delivery.take() case final request?) _open(request);
    });
  }

  void _open(EditorOpenRequest request) {
    final active = context.read<ActiveConnectionCubit>();
    final connection = active.listed(request.connectionId);
    if (connection == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.of(context).editor_open_connection_unavailable)));
      return;
    }
    setState(() => _forEditor = (connectionId: connection.id, delivery: EditorOpenDelivery(request)));
    if (active.state.connection?.id != connection.id) active.select(connection);
  }

  @override
  Widget build(BuildContext context) {
    final connectionId = context.select<ActiveConnectionCubit, String?>((cubit) => cubit.state.connection?.id);
    if (connectionId == null) {
      return PickConnectionFirst(
        icon: Icons.terminal,
        onOpenConnections: () => context.go(ApplicationRoutesConstants.connectionList),
      );
    }
    final forEditor = _forEditor;
    return EditorPage(
      key: ValueKey(connectionId),
      connectionId: connectionId,
      openRequest: forEditor != null && forEditor.connectionId == connectionId ? forEditor.delivery : null,
    );
  }
}
