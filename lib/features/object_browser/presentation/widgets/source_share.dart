import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';
import 'package:libredb_mobile/shared/utils/source_highlighter.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:share_plus/share_plus.dart';

final _log = AppLogger.getLogger('SourceShare');

/// The longest part shared as text; a longer one goes as a file, since Android carries shared text in a Binder
/// transaction of about 1 MB, which a part near Studio's 1,000,000-character bound would exceed.
const sourceShareTextLimit = 100000;

/// The file a part longer than [sourceShareTextLimit] is shared as: UTF-8, named after the object and the part, `.sql`
/// for SQL and `.txt` for anything else.
({String name, String mimeType}) sourceShareFile(ObjectSource source, SourceText part) {
  final sql = SourceHighlighter.isSql(part.language);
  final name =
      '${_fileSafe(source.path.isEmpty ? source.kind : source.path.last)}-${_fileSafe(part.id)}'
      '.${sql ? 'sql' : 'txt'}';
  return (name: name, mimeType: sql ? 'application/sql' : 'text/plain');
}

/// Opens the system share sheet for [part] from the button of [context]: its text up to [sourceShareTextLimit]
/// characters, otherwise a [sourceShareFile] written through [TemporaryShareFiles], removed once the share has ended. A
/// share that fails is shown with its code, and so is a file the phone refuses to remove, which the sign-out removes.
Future<void> shareSourcePart(BuildContext context, {required ObjectSource source, required SourceText part}) async {
  final messenger = ScaffoldMessenger.of(context);
  final s = S.of(context);
  final shareFiles = context.read<TemporaryShareFiles>();
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  void show(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  File? file;
  try {
    if (part.text.length <= sourceShareTextLimit) {
      await SharePlus.instance.share(ShareParams(text: part.text, sharePositionOrigin: origin));
    } else {
      final (:name, :mimeType) = sourceShareFile(source, part);
      file = await shareFiles.write(name, utf8.encode(part.text));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          sharePositionOrigin: origin,
        ),
      );
    }
  } on Exception catch (error) {
    final code = error is PlatformException ? error.code : '${error.runtimeType}';
    _log.warn('source not shared: {}', [code]);
    show(s.browse_source_share_failed(code));
  }
  if (file == null) return;
  try {
    await shareFiles.delete(file);
  } on Exception catch (error) {
    // The type only: the message of a file system error holds the path, which names the object.
    _log.error('shared source file not removed: {}', [error.runtimeType]);
    show(s.browse_source_share_file_left('${error.runtimeType}'));
  }
}

/// [name] with the characters a file name cannot hold replaced, such as the `/` of a Firestore document path.
String _fileSafe(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|\s\x00-\x1f]'), '_');
