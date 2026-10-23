import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/answered.dart';
import 'package:libredb_mobile/shared/models/object_container.dart';

/// The top-level containers of a managed connection, named by its id (`seed:<id>`), for a feature outside the object
/// browser: the databases of a server-level connection, which the SQL editor offers to run in.
///
/// The app provides the object browser's cached repository as this interface too, so a reader here shares its kept
/// answers and spends no more of the user's Studio request budget than Browse does.
abstract class IContainersRepository {
  /// The containers at the top level. [refresh] skips an answer kept from before and replaces it.
  Future<Result<Answered<List<ObjectContainer>>>> containers(String connectionId, {bool refresh = false});
}
