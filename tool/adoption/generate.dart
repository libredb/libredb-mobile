import 'dart:convert';
import 'dart:io';

import 'adoption_series.dart';

/// Writes `assets/adoption.json` from the three series of `libredb/libredb-adoption`.
///
/// `scripts/generate_adoption.sh` fetches the series and runs this; it is not meant to be run by hand, because the
/// repository is private and the fetch needs an authenticated `gh`.
///
/// Usage: `dart run tool/adoption/generate.dart <series-dir> <output-file> <measured-on>`
///
/// It writes nothing when a figure cannot be read, so a failed fetch leaves the committed asset as it was rather
/// than replacing it with zeroes.
void main(List<String> arguments) {
  if (arguments.length != 3) {
    stderr.writeln('usage: dart run tool/adoption/generate.dart <series-dir> <output-file> <measured-on>');
    exit(64);
  }
  final [seriesDir, outputPath, measuredOn] = arguments;

  String read(String name) {
    final file = File('$seriesDir/$name.jsonl');
    if (!file.existsSync()) {
      stderr.writeln('${file.path} is missing; run scripts/generate_adoption.sh rather than this directly');
      exit(66);
    }
    return file.readAsStringSync();
  }

  final Map<String, int> figures;
  try {
    figures = adoptionFiguresFrom(engines: read('engines'), channels: read('channels'), listings: read('listings'));
  } on StateError catch (error) {
    stderr.writeln('${error.message}. The committed asset is left alone.');
    exit(65);
  }

  final asset = {...figures, 'measuredOn': measuredOn};
  File(outputPath).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(asset)}\n');
  stdout.writeln(
    'wrote $outputPath — ${figures['engines']} engines, ${figures['channels']} channels, '
    '${figures['listings']} listings, measured $measuredOn',
  );
}
