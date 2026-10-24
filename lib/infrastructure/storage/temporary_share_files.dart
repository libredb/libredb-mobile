import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

/// The files the app hands to the system share sheet, such as an object source too long to share as text, which hold
/// data of the signed-in account.
///
/// Each file is written to `<temporary directory>/share_files/<random folder>/<name>` and removed once its share has
/// ended. On Android share_plus copies a shared file into `<temporary directory>/share_plus` (the app's cache
/// directory) and keeps the copy until the next share, since the app that receives the share reads that copy after the
/// share sheet has closed. [clear] removes both folders; every sign-out and 'Remove my data' run it.
///
/// No exception names a path: a file name holds the object's name.
class TemporaryShareFiles {
  TemporaryShareFiles({Future<Directory> Function()? temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  /// The folder of the files this class writes.
  static const folder = 'share_files';

  /// The folder share_plus copies a shared file into on Android (share_plus `Share.kt`, `shareCacheFolder`).
  static const sharePlusFolder = 'share_plus';

  final Future<Directory> Function() _temporaryDirectory;

  static final _random = Random.secure();

  /// Writes [bytes] to a new file named [name], a plain file name, and answers it.
  Future<File> write(String name, List<int> bytes) async {
    if (name.isEmpty || name == '.' || name == '..' || name.contains('/') || name.contains(r'\')) {
      throw ArgumentError.value('(${name.length} characters)', 'name', 'is not a plain file name');
    }
    final root = await _temporaryDirectory();
    final id = List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final directory = await Directory('${root.path}/$folder/$id').create(recursive: true);
    try {
      return await File('${directory.path}/$name').writeAsBytes(bytes, flush: true);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  /// Removes [file], written by [write], with its folder; throws when the device refuses.
  ///
  /// The removals here use the synchronous file calls: each folder holds a file or a few, and the session wipe of a
  /// sign-out then never waits for the I/O event loop, which a widget test's fake clock does not run.
  Future<void> delete(File file) async {
    final root = await _temporaryDirectory();
    final directory = file.parent;
    if (directory.parent.path != '${root.path}/$folder') {
      throw ArgumentError.value('(a file of another folder)', 'file', 'was not written by TemporaryShareFiles');
    }
    directory.deleteSync(recursive: true);
  }

  /// Removes every file [write] wrote and the copies share_plus keeps; throws when the device refuses.
  Future<void> clear() async {
    final root = await _temporaryDirectory();
    for (final name in [folder, sharePlusFolder]) {
      final directory = Directory('${root.path}/$name');
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
  }
}
