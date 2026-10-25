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
  authShareFilesNotRemoved('auth.share_files_not_removed'),

  // --- settings ---
  settingsChangeLanguageFailed('settings.change_language_failed'),

  /// 'Remove my data' could not clear a store that keeps data of the signed-in account on this device.
  settingsUserDataNotRemoved('settings.user_data_not_removed'),

  /// The device refused to store the app lock settings.
  settingsAppLockNotSaved('settings.app_lock_not_saved'),

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

  /// The statement is longer than the engine's text bound (a 413 from Studio) or the phone's own cap.
  studioStatementTooLarge('studio.statement_too_large'),

  /// An object search would walk more container and kind pairs than Studio lets one search walk
  /// (`INVENTORY_PAIR_LIMIT`, from Studio 1.1.0); naming fewer kinds narrows it.
  studioSearchPairLimit('studio.search_pair_limit'),

  // --- SQL editor: the statement text kept on the device ---
  /// A saved draft or history cannot be read: its key is gone, the file was changed, or it is of an unknown version.
  editorSavedTextUnreadable('editor.saved_text_unreadable'),

  /// The device refused to store or remove saved statement text.
  editorSavedTextNotStored('editor.saved_text_not_stored'),

  /// A page of Load more of a read dropped without an answer while or after the app was in the background; Studio
  /// cancelled its run.
  editorPageInterrupted('editor.page_interrupted'),

  /// A page of Load more of a text the write check flagged dropped without an answer while or after the app was in the
  /// background; whether its run wrote is unknown.
  editorPageOutcomeUnknown('editor.page_outcome_unknown'),

  // --- Browse ---
  /// The preview of an object's rows dropped without an answer while or after the app was in the background; Studio
  /// cancelled its run.
  browseRowsInterrupted('browse.rows_interrupted'),

  // --- LibreDB Platform (lib/infrastructure/platform/platform_errors.dart maps Platform's codes to these) ---
  /// A Platform call in a build without a Platform target, or a stored Platform session such a build cannot serve.
  platformNotConfigured('platform.not_configured'),
  platformAdminRoleRequired('platform.admin_role_required'),
  platformLicenseAdminSeats('platform.license_admin_seats'),
  platformLicenseUserSeats('platform.license_user_seats'),
  platformLicenseExpired('platform.license_expired'),
  platformLicenseInvalid('platform.license_invalid'),
  platformApiDisabled('platform.api_disabled'),
  platformNotFound('platform.not_found'),

  /// A grant `PUT` refused only on `level`, `subject` or `expiresAt` (`platformGrantWriteError`).
  platformGrantLevelRefused('platform.grant_level_refused'),
  platformGrantSubjectRefused('platform.grant_subject_refused'),
  platformGrantExpiryRefused('platform.grant_expiry_refused'),
  platformValidationFailed('platform.validation_failed'),
  platformIdentityProviderUnavailable('platform.identity_provider_unavailable'),
  platformDirectoryUnavailable('platform.directory_unavailable'),
  platformKeycloakUnavailable('platform.keycloak_unavailable'),
  platformPlanFeatureRequired('platform.plan_feature_required'),
  platformPermissionDenied('platform.permission_denied'),
  platformInternalError('platform.internal_error'),
  platformUnreadableAnswer('platform.unreadable_answer'),

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
