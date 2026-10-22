// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(url) => "Could not open ${url}";

  static String m1(currentVersion, minimumVersion) => "Current: ${currentVersion}  •  Required: ${minimumVersion}";

  static String m2(time) => "Estimated end: ${time}";

  static String m3(email) => "OTP sent to ${email}";

  static String m4(max) => "Password cannot be more than ${max} characters long";

  static String m5(min) => "Password must be at least ${min} characters long";

  static String m6(seconds) => "You can try again in ${seconds} s.";

  static String m7(message) => "Error: ${message}";

  static String m8(count) => "${Intl.plural(count, one: '1 row listed.', other: '${count} rows listed.')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "active": MessageLookupByLibrary.simpleMessage("Active"),
    "admin": MessageLookupByLibrary.simpleMessage("Admin"),
    "app_title": MessageLookupByLibrary.simpleMessage("LibreDB"),
    "apply": MessageLookupByLibrary.simpleMessage("Apply"),
    "authorities": MessageLookupByLibrary.simpleMessage("Authorities"),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "change_password": MessageLookupByLibrary.simpleMessage("Change Password"),
    "change_password_description": MessageLookupByLibrary.simpleMessage(
      "Ensure your account is using a long, random password to stay secure.",
    ),
    "community_contribute": MessageLookupByLibrary.simpleMessage("Contribute"),
    "community_docs": MessageLookupByLibrary.simpleMessage("Documentation"),
    "community_issue": MessageLookupByLibrary.simpleMessage("Open an Issue"),
    "community_source_available": MessageLookupByLibrary.simpleMessage("Source Available"),
    "community_sponsor": MessageLookupByLibrary.simpleMessage("Sponsor"),
    "community_star": MessageLookupByLibrary.simpleMessage("Star & Fork"),
    "community_subtitle": MessageLookupByLibrary.simpleMessage(
      "LibreDB\'s source code is public. Your contributions make it better!",
    ),
    "community_title": MessageLookupByLibrary.simpleMessage("Join the Community"),
    "community_translate": MessageLookupByLibrary.simpleMessage("Translate"),
    "connection_environment": MessageLookupByLibrary.simpleMessage("Environment"),
    "connection_list_empty": MessageLookupByLibrary.simpleMessage("Studio offers you no connection yet"),
    "connection_list_load_failed": MessageLookupByLibrary.simpleMessage("Could not load the connections"),
    "connection_list_subtitle": MessageLookupByLibrary.simpleMessage("Databases Studio offers you"),
    "connection_name": MessageLookupByLibrary.simpleMessage("Name"),
    "connection_target": MessageLookupByLibrary.simpleMessage("Target"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Engine"),
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("No internet connection"),
    "current_password": MessageLookupByLibrary.simpleMessage("Current Password"),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Are you sure you want to delete?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Documentation"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "email": MessageLookupByLibrary.simpleMessage("Email"),
    "email_pattern": MessageLookupByLibrary.simpleMessage("Email must be a valid email address"),
    "email_send": MessageLookupByLibrary.simpleMessage("Send Email"),
    "english": MessageLookupByLibrary.simpleMessage("English"),
    "error_account_password_required": MessageLookupByLibrary.simpleMessage(
      "Both current and new password are required",
    ),
    "error_account_passwords_same": MessageLookupByLibrary.simpleMessage(
      "New password must be different from current password",
    ),
    "error_auth_invalid_access_token": MessageLookupByLibrary.simpleMessage("Invalid access token"),
    "error_auth_login_failed": MessageLookupByLibrary.simpleMessage("Login failed"),
    "error_auth_oidc_config": MessageLookupByLibrary.simpleMessage(
      "Single sign-on is not configured correctly in this app. Contact your administrator.",
    ),
    "error_auth_oidc_discovery": MessageLookupByLibrary.simpleMessage(
      "The identity provider could not be reached. Try again later, or contact your administrator if this continues.",
    ),
    "error_auth_oidc_failed": MessageLookupByLibrary.simpleMessage("Sign-in failed. Please try again."),
    "error_auth_oidc_logout_incomplete": MessageLookupByLibrary.simpleMessage(
      "You are signed out of this app, but your session at the identity provider may still be active.",
    ),
    "error_auth_oidc_no_role": MessageLookupByLibrary.simpleMessage(
      "Your account has no role that allows access to this app. Ask your administrator.",
    ),
    "error_auth_otp_validation": MessageLookupByLibrary.simpleMessage("OTP validation failed"),
    "error_auth_send_otp_failed": MessageLookupByLibrary.simpleMessage("Could not send the OTP code"),
    "error_auth_session_persist_failed": MessageLookupByLibrary.simpleMessage("Could not save the session"),
    "error_generic": MessageLookupByLibrary.simpleMessage("Something went wrong"),
    "error_link_open_failed": m0,
    "error_network_cert_invalid": MessageLookupByLibrary.simpleMessage(
      "The connection could not be verified as secure, so it was blocked. Try again later or on another network.",
    ),
    "error_settings_change_language_failed": MessageLookupByLibrary.simpleMessage("Could not change the language"),
    "error_studio_config_error": MessageLookupByLibrary.simpleMessage(
      "The connection is not configured correctly. Contact your administrator.",
    ),
    "error_studio_connection_not_available": MessageLookupByLibrary.simpleMessage(
      "This connection is not available to you.",
    ),
    "error_studio_custom_connections_disabled": MessageLookupByLibrary.simpleMessage(
      "Studio allows only the connections your administrator set up.",
    ),
    "error_studio_database_auth": MessageLookupByLibrary.simpleMessage(
      "The database refused the connection\'s credentials. Ask your administrator to check them.",
    ),
    "error_studio_database_unreachable": MessageLookupByLibrary.simpleMessage(
      "The database could not be reached. Try again in a moment.",
    ),
    "error_studio_governance_unavailable": MessageLookupByLibrary.simpleMessage(
      "Studio cannot check your access right now. Try again in a moment.",
    ),
    "error_studio_identity_provider_unavailable": MessageLookupByLibrary.simpleMessage(
      "Studio cannot reach the identity provider right now. Try again in a moment.",
    ),
    "error_studio_permission_denied": MessageLookupByLibrary.simpleMessage(
      "The database did not allow this. You may lack a privilege on this object.",
    ),
    "error_studio_query_cancelled": MessageLookupByLibrary.simpleMessage("The statement was cancelled."),
    "error_studio_query_error": MessageLookupByLibrary.simpleMessage("The statement failed."),
    "error_studio_rate_limited": MessageLookupByLibrary.simpleMessage(
      "Too many requests in a short time. Wait a moment and try again.",
    ),
    "error_studio_timeout": MessageLookupByLibrary.simpleMessage("The database did not answer in time."),
    "error_studio_transaction_credential_changed": MessageLookupByLibrary.simpleMessage(
      "Your access to this connection changed, so the transaction was rolled back.",
    ),
    "error_studio_transaction_not_owned": MessageLookupByLibrary.simpleMessage(
      "Another session holds an open transaction on this connection.",
    ),
    "error_studio_unreadable_answer": MessageLookupByLibrary.simpleMessage(
      "Studio sent an answer this app cannot read. The app or Studio may need an update.",
    ),
    "error_user_cannot_delete_admin": MessageLookupByLibrary.simpleMessage("Admin user cannot be deleted"),
    "error_user_no_authorities": MessageLookupByLibrary.simpleMessage("No authorities found"),
    "failed": MessageLookupByLibrary.simpleMessage("Failed"),
    "first_name": MessageLookupByLibrary.simpleMessage("First Name"),
    "forbidden_back_home": MessageLookupByLibrary.simpleMessage("Back to home"),
    "forbidden_message": MessageLookupByLibrary.simpleMessage("You do not have permission to view this page."),
    "forbidden_title": MessageLookupByLibrary.simpleMessage("Access denied"),
    "force_update_button": MessageLookupByLibrary.simpleMessage("Update Now"),
    "force_update_message": MessageLookupByLibrary.simpleMessage(
      "A new version is available. Please update to continue using the app.",
    ),
    "force_update_no_store_link": MessageLookupByLibrary.simpleMessage(
      "Open your app store to install the latest version.",
    ),
    "force_update_store_link_invalid": MessageLookupByLibrary.simpleMessage(
      "The update link is not valid. Open your app store to install the latest version.",
    ),
    "force_update_title": MessageLookupByLibrary.simpleMessage("Update Required"),
    "force_update_versions": m1,
    "forgot_password_description": MessageLookupByLibrary.simpleMessage(
      "Enter your email address and we\'ll send you a link to reset your password.",
    ),
    "help_resources": MessageLookupByLibrary.simpleMessage("Help & Resources"),
    "help_resources_subtitle": MessageLookupByLibrary.simpleMessage("Read the documentation and guides on GitHub"),
    "home": MessageLookupByLibrary.simpleMessage("Home"),
    "idle_timeout_signed_out": MessageLookupByLibrary.simpleMessage("You were signed out due to inactivity."),
    "inactive": MessageLookupByLibrary.simpleMessage("Inactive"),
    "invalid_email": MessageLookupByLibrary.simpleMessage("Invalid email address"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "language_select": MessageLookupByLibrary.simpleMessage("Select Language"),
    "last_name": MessageLookupByLibrary.simpleMessage("Last Name"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
    "login": MessageLookupByLibrary.simpleMessage("Login"),
    "login_brand_description": MessageLookupByLibrary.simpleMessage(
      "Reach the databases LibreDB Studio grants you, from your phone.",
    ),
    "login_brand_headline": MessageLookupByLibrary.simpleMessage("Your databases,\nin your pocket."),
    "login_button": MessageLookupByLibrary.simpleMessage("Login"),
    "login_feature_auth_description": MessageLookupByLibrary.simpleMessage(
      "Sign in with the account your organization manages in Keycloak.",
    ),
    "login_feature_auth_title": MessageLookupByLibrary.simpleMessage("Organization sign-in"),
    "login_feature_credentials_description": MessageLookupByLibrary.simpleMessage(
      "Studio holds every database credential, and the app never stores one.",
    ),
    "login_feature_credentials_title": MessageLookupByLibrary.simpleMessage("No passwords on the phone"),
    "login_feature_query_description": MessageLookupByLibrary.simpleMessage(
      "Look through schemas and run queries on the connections you are given.",
    ),
    "login_feature_query_title": MessageLookupByLibrary.simpleMessage("Browse and query"),
    "login_no_account": MessageLookupByLibrary.simpleMessage("Don\'t have an account? "),
    "login_or": MessageLookupByLibrary.simpleMessage("or"),
    "login_otp_email_instructions": MessageLookupByLibrary.simpleMessage("Enter your email to receive OTP code"),
    "login_password": MessageLookupByLibrary.simpleMessage("Password"),
    "login_sso_button": MessageLookupByLibrary.simpleMessage("Sign in with SSO"),
    "login_sso_subtitle": MessageLookupByLibrary.simpleMessage("Sign in with your organization account."),
    "login_switch_to_dark_mode": MessageLookupByLibrary.simpleMessage("Switch to dark mode"),
    "login_switch_to_light_mode": MessageLookupByLibrary.simpleMessage("Switch to light mode"),
    "login_user_name": MessageLookupByLibrary.simpleMessage("Username"),
    "login_welcome_subtitle": MessageLookupByLibrary.simpleMessage("Enter your credentials to access your account"),
    "login_welcome_title": MessageLookupByLibrary.simpleMessage("Welcome back"),
    "login_with_email": MessageLookupByLibrary.simpleMessage("Login with Email"),
    "logout": MessageLookupByLibrary.simpleMessage("Logout"),
    "logout_stored_data_left": MessageLookupByLibrary.simpleMessage(
      "You were signed out, but some stored data could not be removed from this device.",
    ),
    "logout_sure": MessageLookupByLibrary.simpleMessage("Are you sure you want to logout?"),
    "maintenance_estimated_end": m2,
    "maintenance_message": MessageLookupByLibrary.simpleMessage(
      "We are performing scheduled maintenance. Please check back soon.",
    ),
    "maintenance_retry": MessageLookupByLibrary.simpleMessage("Try Again"),
    "maintenance_title": MessageLookupByLibrary.simpleMessage("Under Maintenance"),
    "max_length_100": MessageLookupByLibrary.simpleMessage("Field cannot be more than 100 characters long"),
    "max_length_20": MessageLookupByLibrary.simpleMessage("Field cannot be more than 20 characters long"),
    "min_length_2": MessageLookupByLibrary.simpleMessage("Field must be at least 2 characters long"),
    "min_length_4": MessageLookupByLibrary.simpleMessage("Field must be at least 4 characters long"),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "new_item": MessageLookupByLibrary.simpleMessage("New"),
    "new_password": MessageLookupByLibrary.simpleMessage("New Password"),
    "next": MessageLookupByLibrary.simpleMessage("Next"),
    "no": MessageLookupByLibrary.simpleMessage("No"),
    "no_changes_made": MessageLookupByLibrary.simpleMessage("No changes made"),
    "no_data": MessageLookupByLibrary.simpleMessage("No Data"),
    "not_found_message": MessageLookupByLibrary.simpleMessage("The page you requested could not be found."),
    "not_found_title": MessageLookupByLibrary.simpleMessage("Page Not Found"),
    "only_numbers": MessageLookupByLibrary.simpleMessage("Only numbers are allowed"),
    "otp_code": MessageLookupByLibrary.simpleMessage("OTP Code"),
    "otp_length": MessageLookupByLibrary.simpleMessage("OTP must be 6 characters long"),
    "otp_sent_to_email": m3,
    "password_forgot": MessageLookupByLibrary.simpleMessage("Forgot Password"),
    "password_hide": MessageLookupByLibrary.simpleMessage("Hide password"),
    "password_max_length": m4,
    "password_min_length": m5,
    "password_show": MessageLookupByLibrary.simpleMessage("Show password"),
    "previous": MessageLookupByLibrary.simpleMessage("Previous"),
    "refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "register": MessageLookupByLibrary.simpleMessage("Register"),
    "register_subtitle": MessageLookupByLibrary.simpleMessage("Create your account"),
    "required_field": MessageLookupByLibrary.simpleMessage("Required Field"),
    "resend_otp_code": MessageLookupByLibrary.simpleMessage("Resend OTP Code"),
    "retry": MessageLookupByLibrary.simpleMessage("Retry"),
    "role": MessageLookupByLibrary.simpleMessage("Role"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "send_otp_code": MessageLookupByLibrary.simpleMessage("Send OTP Code"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "settings_appearance": MessageLookupByLibrary.simpleMessage("Appearance"),
    "settings_change_password_subtitle": MessageLookupByLibrary.simpleMessage("Update your password securely"),
    "settings_licenses": MessageLookupByLibrary.simpleMessage("Licenses"),
    "settings_licenses_subtitle": MessageLookupByLibrary.simpleMessage(
      "The licenses of LibreDB Mobile and the code it includes",
    ),
    "settings_subtitle": MessageLookupByLibrary.simpleMessage("Manage your account preferences"),
    "settings_theme_subtitle": MessageLookupByLibrary.simpleMessage("Choose your preferred theme style"),
    "studio_error_copy_statement": MessageLookupByLibrary.simpleMessage("Copy statement"),
    "studio_error_fix_statement": MessageLookupByLibrary.simpleMessage(
      "An administrator can run this statement to fix it:",
    ),
    "studio_error_retry_in": m6,
    "studio_error_semantics": m7,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("Statement copied"),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "success": MessageLookupByLibrary.simpleMessage("Success"),
    "table_rows_listed": m8,
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "theme_dialog_subtitle": MessageLookupByLibrary.simpleMessage("Select your preferred theme style"),
    "theme_dialog_title": MessageLookupByLibrary.simpleMessage("Choose Theme"),
    "theme_palette_classic": MessageLookupByLibrary.simpleMessage("Classic"),
    "theme_palette_classic_description": MessageLookupByLibrary.simpleMessage("Neutral zinc, clean and minimal"),
    "theme_palette_nature": MessageLookupByLibrary.simpleMessage("Nature"),
    "theme_palette_nature_description": MessageLookupByLibrary.simpleMessage("Sage green, calm and organic"),
    "theme_palette_sunset": MessageLookupByLibrary.simpleMessage("Sunset"),
    "theme_palette_sunset_description": MessageLookupByLibrary.simpleMessage("Warm stone, rich and inviting"),
    "turkish": MessageLookupByLibrary.simpleMessage("Turkish"),
    "unsaved_changes": MessageLookupByLibrary.simpleMessage(
      "You have unsaved changes. Are you sure you want to leave?",
    ),
    "users": MessageLookupByLibrary.simpleMessage("Users"),
    "verify_otp_code": MessageLookupByLibrary.simpleMessage("Verify OTP Code"),
    "warning": MessageLookupByLibrary.simpleMessage("Warning"),
    "yes": MessageLookupByLibrary.simpleMessage("Yes"),
  };
}
