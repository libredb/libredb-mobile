/// Typed registry of error codes the application can emit.
///
/// BLoC error states carry these instead of hardcoded English strings,
/// so the UI can translate them via i18n (see the `AppErrorCodeL10n`
/// extension in `lib/shared/l10n/`).
///
/// The [key] is the *domain-facing* stable identifier — for example, it
/// is what use cases attach to `AppError.code` and what gets logged.
/// Renaming an enum value is safe; changing a [key] is a domain-API
/// break that other layers may match on.
///
/// ARB translation keys (in `lib/l10n/intl_*.arb`) are a separate
/// concern, owned by `AppErrorCodeL10n.resolve(BuildContext)` which
/// maps each enum value to the appropriate `S.of(context).error_*`
/// getter. The two namespaces are intentionally distinct because ARB
/// keys must conform to intl_utils' identifier rules.
enum AppErrorCode {
  // --- auth ---
  authInvalidAccessToken('auth.invalid_access_token'),
  authSessionPersistFailed('auth.session_persist_failed'),
  authOidcConfig('auth.oidc_config'),
  authOidcDiscovery('auth.oidc_discovery'),
  authOidcNoClaims('auth.oidc_no_claims'),
  authOidcFailed('auth.oidc_failed'),
  authOidcLogoutIncomplete('auth.oidc_logout_incomplete'),

  // --- users ---
  userCannotDeleteAdmin('user.cannot_delete_admin'),
  userNoAuthorities('user.no_authorities'),

  // --- settings ---
  settingsChangeLanguageFailed('settings.change_language_failed'),

  // --- network ---
  networkCertInvalid('network.cert_invalid'),

  /// The request was not sent because the device is offline.
  networkOffline('network.offline'),

  // --- LibreDB Studio (lib/infrastructure/studio/studio_errors.dart maps Studio's codes to these) ---
  studioDatabaseAuth('studio.database_auth'),
  studioConnectionNotAvailable('studio.connection_not_available'),
  studioPermissionDenied('studio.permission_denied'),
  studioCustomConnectionsDisabled('studio.custom_connections_disabled'),
  studioQueryError('studio.query_error'),
  studioQueryCancelled('studio.query_cancelled'),
  studioConfigError('studio.config_error'),
  studioTimeout('studio.timeout'),
  studioDatabaseUnreachable('studio.database_unreachable'),
  studioGovernanceUnavailable('studio.governance_unavailable'),
  studioIdentityProviderUnavailable('studio.identity_provider_unavailable'),
  studioAccountRefused('studio.account_refused'),
  studioAccountHasNoRole('studio.account_has_no_role'),
  studioAccountHasNoIdentity('studio.account_has_no_identity'),
  studioRateLimited('studio.rate_limited'),
  studioTransactionNotOwned('studio.transaction_not_owned'),
  studioTransactionCredentialChanged('studio.transaction_credential_changed'),
  studioUnreadableAnswer('studio.unreadable_answer'),

  // --- SQL editor: the statement text kept on the device ---
  /// A saved draft or history cannot be read: its key is gone, the file was changed, or it is of an unknown version.
  editorSavedTextUnreadable('editor.saved_text_unreadable'),

  /// The device refused to store or remove saved statement text.
  editorSavedTextNotStored('editor.saved_text_not_stored'),

  // --- generic fallback ---
  generic('error.generic');

  const AppErrorCode(this.key);

  final String key;

  /// Look up a code by its [key]. Returns null when no enum value
  /// matches — callers should fall back to [AppErrorCode.generic] or
  /// surface the raw message.
  static AppErrorCode? fromKey(String? key) {
    if (key == null) return null;
    for (final code in values) {
      if (code.key == key) return code;
    }
    return null;
  }
}
