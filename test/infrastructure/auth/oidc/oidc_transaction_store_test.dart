import 'package:flutter_bloc_advance/infrastructure/auth/oidc/oidc_transaction_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc/oidc.dart';

void main() {
  late OidcTransactionStore store;

  setUp(() => store = OidcTransactionStore());

  group('OidcTransactionStore', () {
    test('reads back what was set, per namespace', () async {
      await store.setMany(OidcStoreNamespace.state, values: {'s1': 'state-json'});
      await store.setMany(OidcStoreNamespace.secureTokens, values: {'code_verifier.s1': 'verifier'});

      expect(await store.getAllKeys(OidcStoreNamespace.state), {'s1'});
      expect(await store.getMany(OidcStoreNamespace.state, keys: {'s1', 'missing'}), {'s1': 'state-json'});
      expect(await store.getAllKeys(OidcStoreNamespace.stateResponse), isEmpty);
    });

    test('removes the given keys and leaves the others', () async {
      await store.setMany(OidcStoreNamespace.request, values: {'a': '1', 'b': '2'});

      await store.removeMany(OidcStoreNamespace.request, keys: {'a'});

      expect(await store.getMany(OidcStoreNamespace.request, keys: {'a', 'b'}), {'b': '2'});
    });

    test('clearTransactions removes the states, the responses and the secure tokens, and keeps discovery', () async {
      await store.setMany(OidcStoreNamespace.state, values: {'s1': 'state-json'});
      await store.setMany(OidcStoreNamespace.stateResponse, values: {'s1': 'response'});
      await store.setMany(OidcStoreNamespace.secureTokens, values: {'code_verifier.s1': 'verifier', 'nonce': 'n'});
      await store.setMany(OidcStoreNamespace.discoveryDocument, values: {'doc': '{}'});

      await store.clearTransactions();

      expect(await store.getAllKeys(OidcStoreNamespace.state), isEmpty);
      expect(await store.getAllKeys(OidcStoreNamespace.stateResponse), isEmpty);
      expect(await store.getAllKeys(OidcStoreNamespace.secureTokens), isEmpty);
      expect(await store.getAllKeys(OidcStoreNamespace.discoveryDocument), {'doc'});
    });

    test('refuses the session namespace, which the manager does not use', () async {
      expect(() => store.getAllKeys(OidcStoreNamespace.session), throwsUnsupportedError);
      expect(() => store.setMany(OidcStoreNamespace.session, values: {'k': 'v'}), throwsUnsupportedError);
    });
  });
}
