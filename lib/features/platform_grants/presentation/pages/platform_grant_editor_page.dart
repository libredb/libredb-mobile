import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/features/platform_grants/application/directory_picker_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/grant_editor_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/put_grant_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/search_directory_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_directory_repository.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/features/platform_grants/navigation/grant_editor_args.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/widgets/directory_picker_view.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/widgets/grant_editor_form.dart';

/// Gives a user access to a connection, or changes the grant a user holds, in two steps on one route: the directory
/// picker, then the grant form. Opened on a grant, it shows the form at once, prefilled.
///
/// Picking a user who already holds a grant on the connection opens the form on that grant. The page pops with `true`
/// once the grant is saved; whenever a `PUT` may have changed the grant, [GrantEditorArgs.onGrantMayHaveChanged] tells
/// the grants page to read its list again.
class PlatformGrantEditorPage extends StatefulWidget {
  const PlatformGrantEditorPage({super.key, required this.args});

  final GrantEditorArgs args;

  @override
  State<PlatformGrantEditorPage> createState() => _PlatformGrantEditorPageState();
}

class _PlatformGrantEditorPageState extends State<PlatformGrantEditorPage> {
  /// The user picked in the first step; null while the picker shows.
  DirectoryUser? _picked;

  /// The directory search, kept while the form shows, so "choose another user" returns to the same results.
  DirectoryPickerBloc? _picker;

  @override
  void initState() {
    super.initState();
    if (widget.args.grant == null) {
      _picker = DirectoryPickerBloc(
        searchDirectoryUseCase: SearchDirectoryUseCase(context.read<IPlatformDirectoryRepository>()),
      )..add(const DirectoryPickerOpened());
    }
  }

  @override
  void dispose() {
    _picker?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final picker = _picker;
    final picked = _picked;
    if (picker != null && picked == null) {
      return BlocProvider.value(
        value: picker,
        child: DirectoryPickerView(
          target: args.target,
          holders: args.holders,
          onPicked: (user) => setState(() => _picked = user),
        ),
      );
    }
    final grant = picked == null ? args.grant : args.holders[picked.id];
    return BlocProvider(
      key: ValueKey(picked?.id ?? grant?.subject),
      create: (context) => GrantEditorBloc(
        putGrantUseCase: PutGrantUseCase(context.read<IPlatformGrantRepository>()),
        target: args.target,
        user: picked,
        grant: grant,
      ),
      child: BlocListener<GrantEditorBloc, GrantEditorState>(
        // Once when a PUT first may have changed the grant, and again when one saved it, since the list read after
        // an earlier unclear answer may predate the save.
        listenWhen: (previous, current) =>
            (current.mayHaveChanged && !previous.mayHaveChanged) ||
            (current.status == GrantEditorStatus.saved && previous.status != GrantEditorStatus.saved),
        listener: (context, state) {
          args.onGrantMayHaveChanged();
          if (state.status == GrantEditorStatus.saved) context.pop(true);
        },
        child: GrantEditorForm(onChangeUser: picker == null ? null : () => setState(() => _picked = null)),
      ),
    );
  }
}
