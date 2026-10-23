import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/shared/utils/source_highlighter.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:share_plus/share_plus.dart';

final _log = AppLogger.getLogger('SourceShare');

/// The longest part shared as text; a longer one goes as a file, since Android carries shared text in a Binder
/// transaction of about 1 MB, which a part near Studio's 1,000,000-character bound would exceed.
const sourceShareTextLimit = 100000;

/// What the share sheet gets for [part] of [source]: its text up to [sourceShareTextLimit] characters, otherwise a
/// UTF-8 file named after the object and the part, `.sql` for SQL and `.txt` for anything else.
ShareParams sourceShareParams(ObjectSource source, SourceText part, {Rect? origin}) {
  if (part.text.length <= sourceShareTextLimit) return ShareParams(text: part.text, sharePositionOrigin: origin);
  final sql = SourceHighlighter.isSql(part.language);
  final name =
      '${_fileSafe(source.path.isEmpty ? source.kind : source.path.last)}-${_fileSafe(part.id)}'
      '.${sql ? 'sql' : 'txt'}';
  return ShareParams(
    files: [XFile.fromData(utf8.encode(part.text), mimeType: sql ? 'application/sql' : 'text/plain', name: name)],
    fileNameOverrides: [name],
    sharePositionOrigin: origin,
  );
}

/// Opens the system share sheet for [part] from the button of [context]; a share that fails is shown with its code.
Future<void> shareSourcePart(BuildContext context, {required ObjectSource source, required SourceText part}) async {
  final messenger = ScaffoldMessenger.of(context);
  final s = S.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    await SharePlus.instance.share(sourceShareParams(source, part, origin: origin));
  } on Exception catch (error) {
    final code = error is PlatformException ? error.code : '${error.runtimeType}';
    _log.warn('source not shared: {}', [code]);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.browse_source_share_failed(code))));
  }
}

/// [name] with the characters a file name cannot hold replaced, such as the `/` of a Firestore document path.
String _fileSafe(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|\s\x00-\x1f]'), '_');
