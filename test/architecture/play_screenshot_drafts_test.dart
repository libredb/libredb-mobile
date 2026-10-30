import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Guards the phone screenshots of the listing drafts under `android/fastlane/drafts/` (issue #309).
///
/// Play refuses a screenshot that carries an alpha channel, and it refuses a set whose longest side is more than twice
/// its shortest, so a capture taken on a tall phone has to be resized before it enters the repository. Both are silent
/// rejections in the Console, days after the pull request, which is why they are a test here instead: it reads each
/// PNG's IHDR header and fails on the file, not on the upload.
///
/// The checks per image are Play's own graphic requirements: a side of at least 320 and at most 3840 px, a longest side
/// of at least 1080 px so the image is not upscaled in the listing, a long-to-short ratio of at most 2, 8 bits per
/// channel, and a colour type without alpha (0 greyscale or 2 truecolour).
///
/// The checks per draft: each locale holds at least one screenshot, and the locales hold the same file names, so an
/// image added to one language is not forgotten in the other. Play orders the screenshots of a listing by file name,
/// so the names carry the order the listing should read in (`01_login.png`, `02_home.png`, ...).
///
/// `test/architecture/play_listing_metadata_test.dart` guards the listing texts of the same directories; this file
/// never reads a text.
void main() {
  test('each draft locale holds at least one phone screenshot', () {
    final problems = [
      for (final locale in screenshotLocales())
        if (screenshotsOf(locale).isEmpty) '${locale.path} holds no phone screenshot',
    ];

    expect(screenshotLocales(), isNotEmpty, reason: '$draftsRoot holds no locale with screenshots');
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('both locales of a draft hold the same screenshot names', () {
    final problems = <String>[];
    for (final draft in draftDirectories()) {
      final names = {
        for (final locale in _locales)
          locale: [for (final file in screenshotsOf(_localeDirectory(draft, locale))) _name(file.path)],
      };
      if (!_listEquals(names['en-US']!, names['tr-TR']!)) {
        problems.add('${draft.path} holds ${names['en-US']} in en-US and ${names['tr-TR']} in tr-TR');
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('each draft screenshot is a PNG Play accepts', () {
    final problems = [
      for (final locale in screenshotLocales())
        for (final file in screenshotsOf(locale)) ...screenshotProblems(file.path, file.readAsBytesSync()),
    ];

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  group('screenshotProblems', () {
    test('accepts a 1080 by 1920 truecolour PNG without alpha', () {
      expect(screenshotProblems('shot.png', _ihdr(1080, 1920, bitDepth: 8, colourType: 2)), isEmpty);
    });

    test('accepts a greyscale PNG and a square one at the ratio limit', () {
      expect(screenshotProblems('grey.png', _ihdr(1080, 1920, bitDepth: 8, colourType: 0)), isEmpty);
      expect(screenshotProblems('square.png', _ihdr(1080, 1080, bitDepth: 8, colourType: 2)), isEmpty);
      expect(screenshotProblems('wide.png', _ihdr(2160, 1080, bitDepth: 8, colourType: 2)), isEmpty);
    });

    test('names an alpha channel, by colour type', () {
      expect(screenshotProblems('rgba.png', _ihdr(1080, 1920, bitDepth: 8, colourType: 6)), [
        'rgba.png has colour type 6, Play refuses an alpha channel; use 2 (truecolour) or 0 (greyscale)',
      ]);
      expect(screenshotProblems('greya.png', _ihdr(1080, 1920, bitDepth: 8, colourType: 4)), [
        'greya.png has colour type 4, Play refuses an alpha channel; use 2 (truecolour) or 0 (greyscale)',
      ]);
      expect(screenshotProblems('indexed.png', _ihdr(1080, 1920, bitDepth: 8, colourType: 3)), [
        'indexed.png has colour type 3, Play refuses an alpha channel; use 2 (truecolour) or 0 (greyscale)',
      ]);
    });

    test('names a bit depth other than 8', () {
      expect(screenshotProblems('deep.png', _ihdr(1080, 1920, bitDepth: 16, colourType: 2)), [
        'deep.png has 16 bits per channel, Play takes 8',
      ]);
    });

    test('names a ratio above 2, with the sides it measured', () {
      expect(screenshotProblems('tall.png', _ihdr(1080, 2340, bitDepth: 8, colourType: 2)), [
        'tall.png is 1080 by 2340, a ratio of 2.17; Play allows at most 2',
      ]);
    });

    test('names a longest side below 1080 and a side outside Play\'s range', () {
      expect(screenshotProblems('small.png', _ihdr(600, 1000, bitDepth: 8, colourType: 2)), [
        'small.png has a longest side of 1000 px, Play takes at least 1080',
      ]);
      expect(screenshotProblems('tiny.png', _ihdr(200, 1200, bitDepth: 8, colourType: 2)), [
        'tiny.png is 200 by 1200, Play takes a side between 320 and 3840 px',
        'tiny.png is 200 by 1200, a ratio of 6.00; Play allows at most 2',
      ]);
      expect(screenshotProblems('huge.png', _ihdr(3900, 4000, bitDepth: 8, colourType: 2)), [
        'huge.png is 3900 by 4000, Play takes a side between 320 and 3840 px',
      ]);
    });

    test('names a file that is not a PNG', () {
      expect(screenshotProblems('text.png', Uint8List.fromList('not a png at all, really'.codeUnits)), [
        'text.png is not a PNG: it does not start with the PNG signature',
      ]);
      final truncated = _ihdr(1080, 1920, bitDepth: 8, colourType: 2).sublist(0, 20);
      expect(screenshotProblems('short.png', truncated), ['short.png is not a PNG: it is shorter than an IHDR header']);
      final wrongChunk = Uint8List.fromList(_ihdr(1080, 1920, bitDepth: 8, colourType: 2))
        ..setRange(12, 16, 'IDAT'.codeUnits);
      expect(screenshotProblems('chunk.png', wrongChunk), [
        'chunk.png is not a PNG: its first chunk is IDAT, not IHDR',
      ]);
    });
  });
}

const draftsRoot = 'android/fastlane/drafts';
const _locales = ['en-US', 'tr-TR'];

/// Play's graphic requirements for a phone screenshot.
const minimumSide = 320;
const maximumSide = 3840;
const minimumLongestSide = 1080;
const maximumRatio = 2.0;

/// Every `<draft>/<locale>` directory under [draftsRoot] that holds a `images/phoneScreenshots` directory.
List<Directory> screenshotLocales() => [
  for (final draft in draftDirectories())
    for (final locale in _locales)
      if (_localeDirectory(draft, locale).existsSync()) _localeDirectory(draft, locale),
];

/// Every draft directory under [draftsRoot], sorted, so a failure names the same draft on every machine.
List<Directory> draftDirectories() {
  final root = Directory(draftsRoot);
  if (!root.existsSync()) return const [];
  return root.listSync().whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path));
}

/// The PNG files directly under [locale], sorted by name, which is the order Play shows them in.
List<File> screenshotsOf(Directory locale) {
  if (!locale.existsSync()) return const [];
  final files = [
    for (final entry in locale.listSync().whereType<File>())
      if (entry.path.endsWith('.png')) entry,
  ];
  return files..sort((a, b) => _name(a.path).compareTo(_name(b.path)));
}

/// The ways [bytes] breaks Play's requirements for the screenshot at [path], named one problem per line.
///
/// Reads the IHDR header itself rather than decoding the image: the header holds the width, the height, the bit depth
/// and the colour type, and it is the first chunk of every PNG, so no pixel has to be read and no package is needed.
List<String> screenshotProblems(String path, Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 8 || !_startsWith(bytes, signature)) {
    return ['$path is not a PNG: it does not start with the PNG signature'];
  }
  if (bytes.length < 26) return ['$path is not a PNG: it is shorter than an IHDR header'];
  final chunk = String.fromCharCodes(bytes.sublist(12, 16));
  if (chunk != 'IHDR') return ['$path is not a PNG: its first chunk is $chunk, not IHDR'];

  final header = ByteData.sublistView(bytes, 16, 26);
  final width = header.getUint32(0);
  final height = header.getUint32(4);
  final bitDepth = header.getUint8(8);
  final colourType = header.getUint8(9);
  final longest = width > height ? width : height;
  final shortest = width > height ? height : width;

  return [
    if (colourType != 0 && colourType != 2)
      '$path has colour type $colourType, Play refuses an alpha channel; use 2 (truecolour) or 0 (greyscale)',
    if (bitDepth != 8) '$path has $bitDepth bits per channel, Play takes 8',
    if (shortest < minimumSide || longest > maximumSide)
      '$path is $width by $height, Play takes a side between $minimumSide and $maximumSide px',
    if (longest < minimumLongestSide)
      '$path has a longest side of $longest px, Play takes at least $minimumLongestSide',
    if (shortest > 0 && longest / shortest > maximumRatio)
      '$path is $width by $height, a ratio of ${(longest / shortest).toStringAsFixed(2)}; '
          'Play allows at most ${maximumRatio.toStringAsFixed(0)}',
  ];
}

Directory _localeDirectory(Directory draft, String locale) =>
    Directory('${draft.path}/$locale/images/phoneScreenshots');

/// An IHDR header with no chunk after it, for the unit tests above.
Uint8List _ihdr(int width, int height, {required int bitDepth, required int colourType}) {
  final bytes = Uint8List(26);
  bytes.setRange(0, 8, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 13);
  bytes.setRange(12, 16, 'IHDR'.codeUnits);
  data.setUint32(16, width);
  data.setUint32(20, height);
  data.setUint8(24, bitDepth);
  data.setUint8(25, colourType);
  return bytes;
}

bool _startsWith(Uint8List bytes, List<int> prefix) => prefix.indexed.every((e) => bytes[e.$1] == e.$2);

bool _listEquals(List<String> a, List<String> b) => a.length == b.length && a.indexed.every((e) => e.$2 == b[e.$1]);

String _name(String path) => path.replaceAll('\\', '/').split('/').last;
