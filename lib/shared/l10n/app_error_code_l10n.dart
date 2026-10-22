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
      AppErrorCode.authLoginFailed => s.error_auth_login_failed,
      AppErrorCode.authSendOtpFailed => s.error_auth_send_otp_failed,
      AppErrorCode.authOtpValidationError => s.error_auth_otp_validation,
      AppErrorCode.authSessionPersistFailed => s.error_auth_session_persist_failed,
      AppErrorCode.authOidcConfig => s.error_auth_oidc_config,
      AppErrorCode.authOidcDiscovery => s.error_auth_oidc_discovery,
      AppErrorCode.authOidcNoRole => s.error_auth_oidc_no_role,
      AppErrorCode.authOidcNoClaims || AppErrorCode.authOidcFailed => s.error_auth_oidc_failed,
      AppErrorCode.authOidcLogoutIncomplete => s.error_auth_oidc_logout_incomplete,
      AppErrorCode.userCannotDeleteAdmin => s.error_user_cannot_delete_admin,
      AppErrorCode.userNoAuthorities => s.error_user_no_authorities,
      AppErrorCode.accountPasswordRequired => s.error_account_password_required,
      AppErrorCode.accountPasswordsSame => s.error_account_passwords_same,
      AppErrorCode.settingsChangeLanguageFailed => s.error_settings_change_language_failed,
      AppErrorCode.networkCertInvalid => s.error_network_cert_invalid,
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
      AppErrorCode.studioRateLimited => s.error_studio_rate_limited,
      AppErrorCode.studioTransactionNotOwned => s.error_studio_transaction_not_owned,
      AppErrorCode.studioTransactionCredentialChanged => s.error_studio_transaction_credential_changed,
      AppErrorCode.studioUnreadableAnswer => s.error_studio_unreadable_answer,
      AppErrorCode.generic => s.error_generic,
    };
  }
}
