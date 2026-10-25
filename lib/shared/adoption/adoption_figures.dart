import 'dart:convert';

import 'package:equatable/equatable.dart';

/// The adoption figures the onboarding shows: how many database engines LibreDB ships support for, how many channels
/// it is published on, and how many official vendor and project sites list it.
///
/// They are baked in at build time. `scripts/generate_adoption.sh` reads them from the `libredb/libredb-adoption`
/// series and writes `assets/adoption.json`, which is committed, so the app opens no connection for them and shows
/// them offline. Refreshing them is a commit.
///
/// Anything the app cannot read falls back to [fallback] rather than throwing or showing a zero: onboarding runs
/// before the user has signed in or chosen anything, and "0 engines" reaches them as a claim about the product.
final class AdoptionFigures extends Equatable {
  const AdoptionFigures({
    required this.engines,
    required this.channels,
    required this.listings,
    this.measuredOn,
    this.isFallback = false,
  });

  /// The figures shipped in the source, used whenever `assets/adoption.json` cannot be read.
  ///
  /// They were true on the day written below. They go stale, which is the accepted cost of never showing a zero;
  /// update them with the figures of a fresh `scripts/generate_adoption.sh` run.
  static const AdoptionFigures fallback = AdoptionFigures(
    engines: 42,
    channels: 48,
    listings: 31,
    measuredOn: '2026-10-25',
    isFallback: true,
  );

  /// The figures of [json], or [fallback] when any of the three is missing, is not a whole number, or is zero.
  ///
  /// A zero falls back on purpose. The script refuses to write one, so a zero here means the asset was written by
  /// something else, and showing it would state something about LibreDB that is not true.
  factory AdoptionFigures.fromJson(Map<String, dynamic> json) {
    final engines = _figure(json['engines']);
    final channels = _figure(json['channels']);
    final listings = _figure(json['listings']);
    if (engines == null || channels == null || listings == null) return fallback;
    final measuredOn = json['measuredOn'];
    return AdoptionFigures(
      engines: engines,
      channels: channels,
      listings: listings,
      measuredOn: measuredOn is String && measuredOn.isNotEmpty ? measuredOn : null,
    );
  }

  /// The figures of [source], the contents of `assets/adoption.json`, or [fallback] when it is not a JSON object.
  ///
  /// A truncated or empty asset never throws: the bundle can fail to deliver it, and onboarding has to go on.
  factory AdoptionFigures.parse(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? AdoptionFigures.fromJson(decoded) : fallback;
    } on FormatException {
      return fallback;
    }
  }

  /// The database engines LibreDB ships support for.
  final int engines;

  /// The channels LibreDB is published on.
  final int channels;

  /// The official vendor and project sites that list LibreDB.
  final int listings;

  /// The day the figures were measured, as `YYYY-MM-DD`, or null when the asset did not say.
  final String? measuredOn;

  /// Whether these are the figures shipped in the source rather than ones read from the asset.
  final bool isFallback;

  @override
  List<Object?> get props => [engines, channels, listings, measuredOn, isFallback];

  /// [value] as a figure worth showing: a whole number above zero, else null.
  static int? _figure(Object? value) => value is int && value > 0 ? value : null;
}
