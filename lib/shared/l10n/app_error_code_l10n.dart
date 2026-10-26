import 'package:flutter/widgets.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// Translates an [AppErrorCode] into a localized, user-facing message.
///
/// Lives in `shared/l10n/` (not `core/`) because it depends on the
/// generated `S` localization class. `core/errors/` must stay free of
/// Flutter/i18n dependencies.
extension AppErrorCodeL10n on AppErrorCode {
  String resolve(BuildContext context) {
    final s = S.of(context);
    return switch (this) {
      AppErrorCode.authInvalidAccessToken => s.error_auth_invalid_access_token,
      AppErrorCode.authSessionPersistFailed => s.error_auth_session_persist_failed,
      AppErrorCode.authOidcConfig => s.error_auth_oidc_config,
      AppErrorCode.authOidcDiscovery => s.error_auth_oidc_discovery,
      AppErrorCode.authOidcNoClaims || AppErrorCode.authOidcFailed => s.error_auth_oidc_failed,
      AppErrorCode.authOidcLogoutIncomplete => s.error_auth_oidc_logout_incomplete,
      AppErrorCode.authShareFilesNotRemoved => s.error_auth_share_files_not_removed,
      AppErrorCode.settingsChangeLanguageFailed => s.error_settings_change_language_failed,
      AppErrorCode.settingsUserDataNotRemoved => s.error_settings_user_data_not_removed,
      AppErrorCode.settingsAppLockNotSaved => s.error_settings_app_lock_not_saved,
      AppErrorCode.networkCertInvalid => s.error_network_cert_invalid,
      AppErrorCode.networkOffline => s.error_network_offline,
      AppErrorCode.studioDatabaseAuth => s.error_studio_database_auth,
      AppErrorCode.studioConnectionNotAvailable => s.error_studio_connection_not_available,
      AppErrorCode.studioPermissionDenied => s.error_studio_permission_denied,
      AppErrorCode.studioCustomConnectionsDisabled => s.error_studio_custom_connections_disabled,
      AppErrorCode.studioQueryError => s.error_studio_query_error,
      AppErrorCode.studioQueryCancelled => s.error_studio_query_cancelled,
      AppErrorCode.studioConfigError => s.error_studio_config_error,
      AppErrorCode.studioTimeout => s.error_studio_timeout,
      AppErrorCode.studioDatabaseUnreachable => s.error_studio_database_unreachable,
      AppErrorCode.studioGovernanceUnavailable => s.error_studio_governance_unavailable,
      AppErrorCode.studioIdentityProviderUnavailable => s.error_studio_identity_provider_unavailable,
      AppErrorCode.studioAccountRefused => s.error_studio_account_refused,
      AppErrorCode.studioAccountHasNoRole => s.error_studio_account_has_no_role,
      AppErrorCode.studioAccountHasNoIdentity => s.error_studio_account_has_no_identity,
      AppErrorCode.studioRateLimited => s.error_studio_rate_limited,
      AppErrorCode.studioTransactionNotOwned => s.error_studio_transaction_not_owned,
      AppErrorCode.studioTransactionCredentialChanged => s.error_studio_transaction_credential_changed,
      AppErrorCode.studioUnreadableAnswer => s.error_studio_unreadable_answer,
      AppErrorCode.studioStatementTooLarge => s.error_studio_statement_too_large,
      AppErrorCode.studioSearchPairLimit => s.error_studio_search_pair_limit,
      AppErrorCode.studioUnreachable => s.error_studio_unreachable,
      AppErrorCode.editorSavedTextUnreadable => s.error_editor_saved_text_unreadable,
      AppErrorCode.editorSavedTextNotStored => s.error_editor_saved_text_not_stored,
      AppErrorCode.editorPageInterrupted => s.error_editor_page_interrupted,
      AppErrorCode.editorPageOutcomeUnknown => s.error_editor_page_outcome_unknown,
      AppErrorCode.browseRowsInterrupted => s.error_browse_rows_interrupted,
      AppErrorCode.platformNotConfigured => s.error_platform_not_configured,
      AppErrorCode.platformAdminRoleRequired => s.error_platform_admin_role_required,
      AppErrorCode.platformAccountRefused => s.error_platform_account_refused,
      AppErrorCode.platformLicenseAdminSeats => s.error_platform_license_admin_seats,
      AppErrorCode.platformLicenseUserSeats => s.error_platform_license_user_seats,
      AppErrorCode.platformLicenseExpired => s.error_platform_license_expired,
      AppErrorCode.platformLicenseInvalid => s.error_platform_license_invalid,
      AppErrorCode.platformApiDisabled => s.error_platform_api_disabled,
      AppErrorCode.platformNotFound => s.error_platform_not_found,
      AppErrorCode.platformGrantLevelRefused => s.error_platform_grant_level_refused,
      AppErrorCode.platformGrantSubjectRefused => s.error_platform_grant_subject_refused,
      AppErrorCode.platformGrantExpiryRefused => s.error_platform_grant_expiry_refused,
      AppErrorCode.platformValidationFailed => s.error_platform_validation_failed,
      AppErrorCode.platformIdentityProviderUnavailable => s.error_platform_identity_provider_unavailable,
      AppErrorCode.platformDirectoryUnavailable => s.error_platform_directory_unavailable,
      AppErrorCode.platformKeycloakUnavailable => s.error_platform_keycloak_unavailable,
      AppErrorCode.platformPlanFeatureRequired => s.error_platform_plan_feature_required,
      AppErrorCode.platformPermissionDenied => s.error_platform_permission_denied,
      AppErrorCode.platformInternalError => s.error_platform_internal_error,
      AppErrorCode.platformUnreachable => s.error_platform_unreachable,
      AppErrorCode.platformUnreadableAnswer => s.error_platform_unreadable_answer,
      AppErrorCode.generic => s.error_generic,
    };
  }
}
