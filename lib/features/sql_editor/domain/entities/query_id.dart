import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A new id for a run, to cancel it by. Studio checks no owner on a cancel, and without governance one connection is
/// shared by every user, so the id must be unguessable.
String newQueryId() => _uuid.v4();
