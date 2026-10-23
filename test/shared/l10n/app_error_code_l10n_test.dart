@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/golden_app.dart';

void main() {
  /// The English sentence [code] resolves to.
  Future<String> resolved(WidgetTester tester, AppErrorCode code) async {
    late BuildContext context;
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox();
        },
      ),
    );
    await tester.pumpAndSettle();
    return code.resolve(context);
  }

  group('LibreDB Studio error codes', () {
    const sentences = {
      AppErrorCode.studioDatabaseAuth:
          "The database refused the connection's credentials. Ask your administrator to check them.",
      AppErrorCode.studioConnectionNotAvailable: "This connection is not available to you.",
      AppErrorCode.studioPermissionDenied: "The database did not allow this. You may lack a privilege on this object.",
      AppErrorCode.studioCustomConnectionsDisabled: "Studio allows only the connections your administrator set up.",
      AppErrorCode.studioQueryError: "The statement failed.",
      AppErrorCode.studioQueryCancelled: "The statement was cancelled.",
      AppErrorCode.studioConfigError: "The connection is not configured correctly. Contact your administrator.",
      AppErrorCode.studioTimeout: "The database did not answer in time.",
      AppErrorCode.studioDatabaseUnreachable: "The database could not be reached. Try again in a moment.",
      AppErrorCode.studioGovernanceUnavailable: "Studio cannot check your access right now. Try again in a moment.",
      AppErrorCode.studioIdentityProviderUnavailable:
          "Studio cannot reach the identity provider right now. Try again in a moment.",
      AppErrorCode.studioAccountRefused:
          "Studio did not accept this sign-in. Try again, or ask an administrator for access.",
      AppErrorCode.studioAccountHasNoRole: "This account has no role in Studio. Ask an administrator to give it one.",
      AppErrorCode.studioAccountHasNoIdentity:
          "Studio cannot tell who this account is. Ask an administrator to check the account's email and username.",
      AppErrorCode.studioRateLimited: "Too many requests in a short time. Wait a moment and try again.",
      AppErrorCode.studioTransactionNotOwned: "Another session holds an open transaction on this connection.",
      AppErrorCode.studioTransactionCredentialChanged:
          "Your access to this connection changed, so the transaction was rolled back.",
      AppErrorCode.studioUnreadableAnswer:
          "Studio sent an answer this app cannot read. The app or Studio may need an update.",
    };

    for (final MapEntry(key: code, value: sentence) in sentences.entries) {
      testWidgets('${code.name} resolves to its English sentence', (tester) async {
        expect(await resolved(tester, code), sentence);
      });
    }
  });

  group('SQL editor error codes', () {
    const sentences = {
      AppErrorCode.editorSavedTextUnreadable:
          'The statement text saved on this phone cannot be read. It may have come from a backup of another device, '
          'or the file was changed. Discard it to keep new text again.',
      AppErrorCode.editorSavedTextNotStored:
          'This phone could not save the statement text. Check its free storage and try again.',
    };

    for (final MapEntry(key: code, value: sentence) in sentences.entries) {
      testWidgets('${code.name} resolves to its English sentence', (tester) async {
        expect(await resolved(tester, code), sentence);
      });
    }
  });

  group('single sign-on error codes', () {
    const sentences = {
      AppErrorCode.authOidcConfig:
          'Single sign-on is not configured correctly in this app. Contact your administrator.',
      AppErrorCode.authOidcDiscovery: 'The identity provider could not be reached. Try again later, or contact your administrator if this continues.',
      AppErrorCode.authOidcNoClaims: 'Sign-in failed. Please try again.',
      AppErrorCode.authOidcFailed: 'Sign-in failed. Please try again.',
      AppErrorCode.authOidcLogoutIncomplete:
          'You are signed out of this app, but your session at the identity provider may still be active.',
    };

    for (final MapEntry(key: code, value: sentence) in sentences.entries) {
      testWidgets('${code.name} resolves to its English sentence', (tester) async {
        expect(await resolved(tester, code), sentence);
      });
    }

    testWidgets('authOidcNoClaims shows the same sentence as authOidcFailed', (tester) async {
      expect(
        await resolved(tester, AppErrorCode.authOidcNoClaims),
        await resolved(tester, AppErrorCode.authOidcFailed),
      );
    });
  });
}
