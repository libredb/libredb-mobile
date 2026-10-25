/// The body of LibreDB Platform's `PUT /api/v1/connections/{id}/grants/{subject}`: a strict object of exactly `level`
/// and `expiresAt`, both required, which Platform refuses with any other key (libredb-platform
/// `src/features/connections/lib/grant.schema.ts`).
final class GrantPutBody {
  /// The body of a grant of [level] that ends at [expiresAt], or never when it is null.
  const GrantPutBody({required this.level, required this.expiresAt});

  final String level;
  final DateTime? expiresAt;

  /// `{"level": level, "expiresAt": "<UTC ISO 8601>" | null}`; the `expiresAt` key is there for a grant that does not
  /// expire too, with JSON null.
  Map<String, Object?> toJson() => {'level': level, 'expiresAt': expiresAt?.toUtc().toIso8601String()};
}
