/// The closed and named values of LibreDB Platform's audit log (libredb-platform
/// `src/shared/lib/bridge/query-event-vocabulary.ts`), the choices of the filter sheet.
abstract final class AuditVocabulary {
  /// Every status an event can have.
  static const statuses = ['success', 'error', 'cancelled', 'refused'];

  /// Every statement type an event can have.
  static const statementTypes = ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DDL', 'OTHER'];

  /// The sources Platform names; the vocabulary is open, so an event can carry another one.
  static const sources = [
    'editor',
    'multi-query',
    'transaction',
    'object-edit',
    'maintenance',
    'profile',
    'key-scan',
    'agent',
    'agent-handover',
    'mcp',
  ];
}
