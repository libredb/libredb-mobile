import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';

void main() {
  late Directory temporary;
  late TemporaryShareFiles files;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('temporary_share_files');
    files = TemporaryShareFiles(temporaryDirectory: () async => temporary);
  });

  tearDown(() {
    if (temporary.existsSync()) temporary.deleteSync(recursive: true);
  });

  List<String> left() => [
    for (final entity in temporary.listSync(recursive: true))
      if (entity is File) entity.path.substring(temporary.path.length + 1),
  ]..sort();

  test('writes the bytes to a file of the name under its own folder of the temporary directory', () async {
    final file = await files.write('order_totals-definition.sql', [83, 69, 76]);

    expect(file.path, startsWith('${temporary.path}/share_files/'));
    expect(file.path, endsWith('/order_totals-definition.sql'));
    expect(file.readAsBytesSync(), [83, 69, 76]);
  });

  test('two files of one name are kept apart', () async {
    final first = await files.write('a.sql', [1]);
    final second = await files.write('a.sql', [2]);

    expect(first.path, isNot(second.path));
    expect(first.readAsBytesSync(), [1]);
    expect(second.readAsBytesSync(), [2]);
  });

  test('refuses a name that is not a plain file name', () async {
    for (final name in ['', '.', '..', 'a/b.sql', r'a\b.sql']) {
      await expectLater(files.write(name, [1]), throwsArgumentError, reason: name);
    }
    expect(left(), isEmpty);
  });

  test('delete removes the file and its folder, and leaves the other files', () async {
    final first = await files.write('a.sql', [1]);
    final second = await files.write('b.sql', [2]);

    await files.delete(first);

    expect(first.parent.existsSync(), isFalse);
    expect(second.existsSync(), isTrue);
  });

  // A sign-out while the share sheet was open cleared the folder already, so the removal has nothing left to do.
  test('delete of a file a clear already removed succeeds', () async {
    final file = await files.write('a.sql', [1]);
    await files.clear();

    await files.delete(file);

    expect(left(), isEmpty);
  });

  test('delete throws when the device refuses the removal', () async {
    final file = await files.write('a.sql', [1]);
    // A folder the app cannot write to keeps the share's folder in it.
    final shareFolder = file.parent.parent.path;
    Process.runSync('chmod', ['555', shareFolder]);
    addTearDown(() => Process.runSync('chmod', ['755', shareFolder]));

    await expectLater(files.delete(file), throwsA(isA<FileSystemException>()));
    expect(file.parent.existsSync(), isTrue);
  });

  test('delete refuses a file that is not one of its own', () async {
    final other = File('${temporary.path}/other.txt')..writeAsStringSync('x');

    await expectLater(files.delete(other), throwsArgumentError);
    expect(other.existsSync(), isTrue);
  });

  test('clear removes its files and the copies share_plus keeps, and nothing else', () async {
    await files.write('a.sql', [1]);
    File('${temporary.path}/share_plus/a.sql')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    File('${temporary.path}/other/kept.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('x');

    await files.clear();

    expect(left(), ['other/kept.txt']);
  });

  test('clear with nothing to remove succeeds', () async {
    await files.clear();

    expect(left(), isEmpty);
  });

  test('clear throws when the device refuses the removal', () async {
    final unreachable = TemporaryShareFiles(temporaryDirectory: () async => throw const FileSystemException('refused'));

    await expectLater(unreachable.clear(), throwsA(isA<FileSystemException>()));
  });
}
