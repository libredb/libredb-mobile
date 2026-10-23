/// A size in bytes as people read it, in steps of 1024: `1023 B`, `1.5 KB`, `32 KB`, `1.8 MB`.
///
/// Below ten of a unit it keeps one decimal, above it rounds to a whole number; terabytes are the largest unit.
/// A negative size is no size, so it throws an [ArgumentError].
String formatByteSize(int bytes) {
  if (bytes < 0) throw ArgumentError.value(bytes, 'bytes', 'must not be negative');
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value < 10 ? value.toStringAsFixed(1) : value.round()} ${units[unit]}';
}
