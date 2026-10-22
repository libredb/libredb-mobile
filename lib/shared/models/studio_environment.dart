/// The environments Studio names a connection with, in the order its own types list them
/// (libredb-studio `src/lib/types.ts`, `ConnectionEnvironment`).
///
/// [StudioConnection.environment] keeps whatever string Studio sent; one outside this list is shown as it is.
abstract final class StudioEnvironment {
  static const production = 'production';
  static const staging = 'staging';
  static const development = 'development';
  static const local = 'local';
  static const other = 'other';

  static const ordered = [production, staging, development, local, other];

  /// The badge text Studio's sidebar shows for [environment] (`ENVIRONMENT_LABELS` in `src/lib/types.ts`), null for
  /// `other`, which Studio shows no badge for, and the string as it was sent for an environment Studio does not name.
  static String? label(String environment) => switch (environment) {
    production => 'PROD',
    staging => 'STAGING',
    development => 'DEV',
    local => 'LOCAL',
    other => null,
    _ => environment,
  };
}
