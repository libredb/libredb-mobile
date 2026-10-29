import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';

/// A request of the signed-in user, pending unless [status] says otherwise.
MyAccessRequest fixtureRequest(
  String id, {
  String status = 'pending',
  String level = 'read',
  String connectionName = 'Analytics warehouse',
  String? decisionReason,
}) => MyAccessRequest(
  id: id,
  connectionId: 'c-$id',
  connectionName: connectionName,
  connectionEngine: 'postgres',
  connectionStatus: 'active',
  level: level,
  reason: 'The October report',
  status: AccessRequestStatus.of(status),
  rawStatus: status,
  createdAt: DateTime.utc(2026, 10, 29, 9, 30),
  decidedAt: status == 'pending' ? null : DateTime.utc(2026, 10, 30, 8),
  decisionReason: decisionReason,
  grantId: status == 'approved' ? 'g-$id' : null,
);

/// A connection the user can ask for: nothing held and nothing pending unless given.
RequestableConnection fixtureConnection(
  String id, {
  String? name,
  bool write = true,
  String? heldLevel,
  String? pendingRequestId,
}) => RequestableConnection(
  id: id,
  name: name ?? 'Connection $id',
  engine: 'postgres',
  hasWriteCredential: write,
  access: heldLevel == null ? null : ConnectionAccess(level: heldLevel, expiresAt: null),
  pendingRequestId: pendingRequestId,
);
