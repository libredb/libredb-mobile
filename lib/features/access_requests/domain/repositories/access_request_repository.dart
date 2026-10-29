import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/requestable_connection.dart';

/// The access a Studio user asks LibreDB Platform for, through Platform's requester routes.
///
/// Every method here is called under a Studio session: the token carries the Studio user role, no Platform user is
/// provisioned and no license seat is taken. A Platform refusal never ends or refuses the Studio session; the screen
/// shows it.
abstract class IAccessRequestRepository {
  /// The active connections the caller may ask for, by name, each with the access they already hold and the id of
  /// their open request for it (`GET /api/v1/requester/connections`).
  Future<Result<List<RequestableConnection>>> requestableConnections();

  /// The caller's own newest 50 requests, in Platform's order (`GET /api/v1/requester/access-requests`).
  Future<Result<List<MyAccessRequest>>> mine();

  /// Asks for [level] (`read` or `write`) on the connection [connectionId], saying why in [reason], which Platform
  /// counts as 1 to 500 characters after trimming (`POST /api/v1/requester/access-requests`).
  ///
  /// A refusal on `reason` or `level` answers that field's code; an open request, access already held or too many
  /// requests answer `platformAccessRequestPending`, `platformAccessAlreadyGranted` or `platformAccessRequestLimit`.
  /// It is never sent twice.
  Future<Result<MyAccessRequest>> create({required String connectionId, required String level, required String reason});

  /// Withdraws the caller's open request [requestId] and answers it as Platform now holds it
  /// (`POST /api/v1/requester/access-requests/{id}/withdraw`).
  ///
  /// An unknown request, or another user's, answers `platformNotFound`; one already decided answers
  /// `platformAccessRequestDecided`. It is never sent twice.
  Future<Result<MyAccessRequest>> withdraw(String requestId);
}
