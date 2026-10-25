import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/security/sensitive_data_scrubber.dart';

/// Whether [path] is under `/v1/`, LibreDB Platform's bearer API relative to its `/api`; no Studio path is.
bool isPlatformPath(String path) => (path.startsWith('/') ? path : '/$path').startsWith('/v1/');

/// The URI of [options] as a log line or the dev console shows it.
///
/// A LibreDB Platform request keeps its query keys and has every value replaced by [secretMask], because the directory
/// search text and the audit filters can name a person or quote a statement. Any other request is shown as it is.
String loggedUri(RequestOptions options) {
  final uri = options.uri;
  if (!uri.hasQuery || !isPlatformPath(options.path)) return uri.toString();
  final text = uri.toString();
  final query = [
    for (final MapEntry(:key, :value) in uri.queryParametersAll.entries)
      for (final _ in value) '${Uri.encodeQueryComponent(key)}=$secretMask',
  ];
  return '${text.substring(0, text.indexOf('?'))}?${query.join('&')}';
}
