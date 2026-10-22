import 'package:oidc/oidc.dart';

/// The app-owned [OidcStore] of the OIDC user manager: memory that lives only as long as the app run.
///
/// A sign-in completes within one run, in the browser the app opens and closes, so nothing the manager stores needs to
/// outlive it, and the app's session storage owns the tokens. `session` is unused by the manager and refused.
final class OidcTransactionStore implements OidcStore {
  OidcTransactionStore();

  final _namespaces = <OidcStoreNamespace, Map<String, String>>{};

  @override
  Future<void> init() async {}

  @override
  Future<Set<String>> getAllKeys(OidcStoreNamespace namespace, {String? managerId}) async =>
      _of(namespace).keys.toSet();

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) async {
    final values = _of(namespace);
    return {for (final key in keys) key: ?values[key]};
  }

  @override
  Future<void> setMany(OidcStoreNamespace namespace, {required Map<String, String> values, String? managerId}) async =>
      _of(namespace).addAll(values);

  @override
  Future<void> removeMany(OidcStoreNamespace namespace, {required Set<String> keys, String? managerId}) async =>
      _of(namespace).removeWhere((key, _) => keys.contains(key));

  /// Removes every transaction: the states, their responses, and the PKCE verifiers and nonce, with the rest of the
  /// manager's `secureTokens`.
  Future<void> clearTransactions() async {
    for (final namespace in const [
      OidcStoreNamespace.state,
      OidcStoreNamespace.stateResponse,
      OidcStoreNamespace.secureTokens,
    ]) {
      _namespaces.remove(namespace);
    }
  }

  Map<String, String> _of(OidcStoreNamespace namespace) {
    if (namespace == OidcStoreNamespace.session) throw UnsupportedError('the session namespace is not used');
    return _namespaces[namespace] ??= {};
  }
}
