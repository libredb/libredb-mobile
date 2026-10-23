import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The names of the routes under the Browse root, which a page opens with `pushNamed`.
class BrowseRouteNames {
  static const browse = 'browse';
  static const containers = 'browseContainers';
  static const kinds = 'browseKinds';
  static const objects = 'browseObjects';
  static const source = 'browseSource';
}

/// The query key that carries a container path, once per segment and in order.
const browseContainerKey = 'container';

/// The query key that carries an object path, once per segment and in order.
const browsePathKey = 'path';

/// The path parameter that names an object's kind.
const browseKindKey = 'kind';

/// The path parameter that names the connection.
const browseConnectionIdKey = 'connectionId';

/// The connection named by the route of [state].
String browseConnectionIdOf(GoRouterState state) => state.pathParameters[browseConnectionIdKey]!;

/// The container path carried by the route of [state], empty when the route names none.
List<String> browseContainerOf(GoRouterState state) =>
    List.unmodifiable(state.uri.queryParametersAll[browseContainerKey] ?? const <String>[]);

/// The object path carried by the route of [state], empty when the route names none.
List<String> browsePathOf(GoRouterState state) =>
    List.unmodifiable(state.uri.queryParametersAll[browsePathKey] ?? const <String>[]);

/// The kind named by the route of [state].
String browseKindOf(GoRouterState state) => state.pathParameters[browseKindKey]!;

/// Opens the level of [connectionId]'s containers under [parent].
void openBrowseContainers(BuildContext context, String connectionId, List<String> parent) => context.pushNamed(
  BrowseRouteNames.containers,
  pathParameters: {browseConnectionIdKey: connectionId},
  queryParameters: _containerQuery(parent),
);

/// Opens the kind screen of [container] of [connectionId].
void openBrowseKinds(BuildContext context, String connectionId, List<String> container) => context.pushNamed(
  BrowseRouteNames.kinds,
  pathParameters: {browseConnectionIdKey: connectionId},
  queryParameters: _containerQuery(container),
);

/// Opens the source of the object at [path] of [connectionId], of [kind].
void openBrowseSource(BuildContext context, String connectionId, List<String> path, String kind) => context.pushNamed(
  BrowseRouteNames.source,
  pathParameters: {browseConnectionIdKey: connectionId, browseKindKey: kind},
  queryParameters: path.isEmpty ? const <String, dynamic>{} : <String, dynamic>{browsePathKey: path},
);

/// Opens the objects of [kind] in [container] of [connectionId].
void openBrowseObjects(BuildContext context, String connectionId, List<String> container, String kind) =>
    context.pushNamed(
      BrowseRouteNames.objects,
      pathParameters: {browseConnectionIdKey: connectionId, browseKindKey: kind},
      queryParameters: _containerQuery(container),
    );

/// A container path as repeated query values, which `Uri` encodes one by one, so a name holding `/`, `&` or a space
/// comes back as it was; an empty path leaves the key out.
Map<String, dynamic> _containerQuery(List<String> path) =>
    path.isEmpty ? const <String, dynamic>{} : <String, dynamic>{browseContainerKey: path};
