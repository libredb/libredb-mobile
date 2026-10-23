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

  static String m0(code) => "Could not count the rows (${code})";

  static String m1(value) => "Default: ${value}";

  static String m2(code) => "Could not check which tables these keys open (${code})";

  static String m3(table, column) => "References ${table}.${column}";

  static String m4(type) => "${type} (sampled)";

  static String m5(parent) => "On ${parent}";

  static String m6(count, formatted) => "${Intl.plural(count, one: '1 row', other: '${formatted} rows')}";

  static String m7(count, formatted) => "${Intl.plural(count, one: '1 object', other: '${formatted} objects')}";

  static String m8(matched, total) => "${matched} of ${total} match";

  static String m9(count) => "Type at least ${count} characters to search.";

  static String m10(term) => "No object\'s name holds \"${term}\".";

  static String m11(code) => "Could not copy (${code})";

  static String m12(code) => "Could not share (${code})";

  static String m13(reason) => "Truncated: ${reason}";

  static String m14(latency) => "Reachable, ${latency} ms";

  static String m15(label) => "Environment: ${label}";

  static String m16(status) => "Status: ${status}";

  static String m17(name) => "${name} is no longer available";

  static String m18(url) => "Could not open ${url}";

  static String m19(currentVersion, minimumVersion) => "Current: ${currentVersion}  •  Required: ${minimumVersion}";

  static String m20(count) => "${Intl.plural(count, one: 'Listed 1 entry', other: 'Listed ${count} entries')}";

  static String m21(count) =>
      "${Intl.plural(count, one: 'Listed 1 entry; more remain', other: 'Listed ${count} entries; more remain')}";

  static String m22(reason) => "This list is incomplete, and the engine can show why: ${reason}";

  static String m23(reason) =>
      "This list is what the read saw. Whether it is everything cannot be established on this engine: ${reason}";

  static String m24(count) => "${Intl.plural(count, one: 'Scanned 1 key', other: 'Scanned ${count} keys')}";

  static String m25(count) =>
      "${Intl.plural(count, one: 'Scanned 1 key; more remain', other: 'Scanned ${count} keys; more remain')}";

  static String m26(count, total) => "Scanned ${count} of the ${total} keys this database holds";

  static String m27(count, total) => "Scanned ${count} of the ${total} keys this database holds; more remain";

  static String m28(count, total) => "Scanned ${count} of the ${total} keys this walk covers";

  static String m29(count, total) => "Scanned ${count} of the ${total} keys this walk covers; more remain";

  static String m30(count, reason) =>
      "${Intl.plural(count, one: '1 key left out of this walk: ${reason}', other: '${count} keys left out of this walk: ${reason}')}";

  static String m31(type) => "Studio says this key\'s type is ${type}.";

  static String m32(time) => "Estimated end: ${time}";

  static String m33(time) => "Offline: showing what was loaded at ${time}";

  static String m34(count, rows) => "${Intl.plural(count, one: '1 row affected', other: '${rows} rows affected')}";

  static String m35(id) => "#${id}";

  static String m36(code) => "Could not copy (${code})";

  static String m37(count, rows) => "${Intl.plural(count, one: 'Load 1 more', other: 'Load ${rows} more')}";

  static String m38(count, rows) => "${Intl.plural(count, one: 'Loading 1 more…', other: 'Loading ${rows} more…')}";

  static String m39(count) => "${Intl.plural(count, one: '+1 more field', other: '+${count} more fields')}";

  static String m40(index, count) => "Row ${index} of ${count}";

  static String m41(index) => "Row ${index}";

  static String m42(count, rows, time) =>
      "${Intl.plural(count, one: '1 row, ${time} ms', other: '${rows} rows, ${time} ms')}";

  static String m43(code) => "Code ${code}";

  static String m44(severity, message) => "${severity}: ${message}";

  static String m45(count) => "${Intl.plural(count, one: '1 warning', other: '${count} warnings')}";

  static String m46(seconds) => "You can try again in ${seconds} s.";

  static String m47(message) => "Error: ${message}";

  static String m48(detail) => "Details: ${detail}";

  static String m49(host) => "Studio address: ${host}";

  static String m50(count) => "${Intl.plural(count, one: '1 row listed.', other: '${count} rows listed.')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "account_refusal_title": MessageLookupByLibrary.simpleMessage("Your account has no access to Studio"),
    "active": MessageLookupByLibrary.simpleMessage("Active"),
    "admin": MessageLookupByLibrary.simpleMessage("Admin"),
    "app_title": MessageLookupByLibrary.simpleMessage("LibreDB"),
    "apply": MessageLookupByLibrary.simpleMessage("Apply"),
    "authorities": MessageLookupByLibrary.simpleMessage("Authorities"),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "browse_count_failed": m0,
    "browse_count_rows": MessageLookupByLibrary.simpleMessage("Count rows"),
    "browse_detail_columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "browse_detail_default": m1,
    "browse_detail_exclusion_constraints": MessageLookupByLibrary.simpleMessage("Exclusion constraints"),
    "browse_detail_foreign_keys": MessageLookupByLibrary.simpleMessage("Foreign keys"),
    "browse_detail_indexes": MessageLookupByLibrary.simpleMessage("Indexes"),
    "browse_detail_links_unchecked": m2,
    "browse_detail_no_columns": MessageLookupByLibrary.simpleMessage("Studio lists no columns."),
    "browse_detail_no_foreign_keys": MessageLookupByLibrary.simpleMessage("Studio lists no foreign keys."),
    "browse_detail_no_indexes": MessageLookupByLibrary.simpleMessage("Studio lists no indexes."),
    "browse_detail_nullable": MessageLookupByLibrary.simpleMessage("Nullable"),
    "browse_detail_primary_key": MessageLookupByLibrary.simpleMessage("Primary key"),
    "browse_detail_references": m3,
    "browse_detail_sampled": MessageLookupByLibrary.simpleMessage("Columns inferred from sampled documents"),
    "browse_detail_sampled_type": m4,
    "browse_detail_unique": MessageLookupByLibrary.simpleMessage("Unique"),
    "browse_details": MessageLookupByLibrary.simpleMessage("Details"),
    "browse_kinds_empty": MessageLookupByLibrary.simpleMessage("Studio counts no objects here."),
    "browse_level_empty": MessageLookupByLibrary.simpleMessage("Studio lists nothing at this level."),
    "browse_object_attached_to": m5,
    "browse_object_copy_name": MessageLookupByLibrary.simpleMessage("Copy name"),
    "browse_object_name_copied": MessageLookupByLibrary.simpleMessage("Name copied"),
    "browse_object_rows": m6,
    "browse_object_status_disabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "browse_object_status_invalid": MessageLookupByLibrary.simpleMessage("Invalid"),
    "browse_object_view_source": MessageLookupByLibrary.simpleMessage("View source"),
    "browse_objects": MessageLookupByLibrary.simpleMessage("Objects"),
    "browse_objects_count": m7,
    "browse_objects_empty": MessageLookupByLibrary.simpleMessage("Studio lists no objects of this kind here."),
    "browse_objects_match": m8,
    "browse_preview_unavailable": MessageLookupByLibrary.simpleMessage("Preview is not available for this engine yet"),
    "browse_rows_database_says": MessageLookupByLibrary.simpleMessage("The database says"),
    "browse_search_action": MessageLookupByLibrary.simpleMessage("Search objects"),
    "browse_search_clear": MessageLookupByLibrary.simpleMessage("Clear search"),
    "browse_search_hint": MessageLookupByLibrary.simpleMessage("Search by name"),
    "browse_search_min_length": m9,
    "browse_search_no_results": m10,
    "browse_search_not_available": MessageLookupByLibrary.simpleMessage(
      "Search is not available on this connection; browse instead",
    ),
    "browse_search_title": MessageLookupByLibrary.simpleMessage("Search"),
    "browse_source": MessageLookupByLibrary.simpleMessage("Source"),
    "browse_source_copied": MessageLookupByLibrary.simpleMessage("Copied"),
    "browse_source_copy": MessageLookupByLibrary.simpleMessage("Copy all"),
    "browse_source_copy_failed": m11,
    "browse_source_partial": MessageLookupByLibrary.simpleMessage("Partial"),
    "browse_source_regenerated": MessageLookupByLibrary.simpleMessage("Regenerated by Studio, not the stored text"),
    "browse_source_share": MessageLookupByLibrary.simpleMessage("Share"),
    "browse_source_share_failed": m12,
    "browse_source_truncated": m13,
    "browse_source_unavailable": MessageLookupByLibrary.simpleMessage("This definition could not be read"),
    "browse_view_rows": MessageLookupByLibrary.simpleMessage("View rows"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cell_null_semantics": MessageLookupByLibrary.simpleMessage("Null value"),
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
    "connection_active": MessageLookupByLibrary.simpleMessage("Active connection"),
    "connection_check": MessageLookupByLibrary.simpleMessage("Check"),
    "connection_check_anyway": MessageLookupByLibrary.simpleMessage("Check anyway"),
    "connection_check_checking": MessageLookupByLibrary.simpleMessage("Checking"),
    "connection_check_degraded": MessageLookupByLibrary.simpleMessage("Reachable, without health data"),
    "connection_check_failed": MessageLookupByLibrary.simpleMessage("Check failed"),
    "connection_check_idle": MessageLookupByLibrary.simpleMessage("Not checked yet"),
    "connection_check_not_checked": MessageLookupByLibrary.simpleMessage(
      "Not checked: checking would start billed compute",
    ),
    "connection_check_online": m14,
    "connection_check_online_no_latency": MessageLookupByLibrary.simpleMessage("Reachable"),
    "connection_database": MessageLookupByLibrary.simpleMessage("Database"),
    "connection_environment": MessageLookupByLibrary.simpleMessage("Environment"),
    "connection_environment_badge": m15,
    "connection_environment_filter": MessageLookupByLibrary.simpleMessage("Filter by environment"),
    "connection_environment_other": MessageLookupByLibrary.simpleMessage("Other"),
    "connection_favorites": MessageLookupByLibrary.simpleMessage("Favorites"),
    "connection_group": MessageLookupByLibrary.simpleMessage("Group"),
    "connection_group_other": MessageLookupByLibrary.simpleMessage("Other"),
    "connection_host": MessageLookupByLibrary.simpleMessage("Host"),
    "connection_list_empty": MessageLookupByLibrary.simpleMessage("No connections are available to you"),
    "connection_list_empty_governed": MessageLookupByLibrary.simpleMessage(
      "No databases have been granted to you yet. Ask an administrator for access.",
    ),
    "connection_list_load_failed": MessageLookupByLibrary.simpleMessage("Could not load the connections"),
    "connection_list_unavailable": MessageLookupByLibrary.simpleMessage("Connections are unavailable"),
    "connection_read_only": MessageLookupByLibrary.simpleMessage("Read only"),
    "connection_recent": MessageLookupByLibrary.simpleMessage("Recent"),
    "connection_search_clear": MessageLookupByLibrary.simpleMessage("Clear search"),
    "connection_search_hint": MessageLookupByLibrary.simpleMessage("Search connections"),
    "connection_search_no_match": MessageLookupByLibrary.simpleMessage("No connections match"),
    "connection_star": MessageLookupByLibrary.simpleMessage("Add to favorites"),
    "connection_statement_capture_full": MessageLookupByLibrary.simpleMessage(
      "Statements you run are recorded in full in this server\'s query log.",
    ),
    "connection_status": MessageLookupByLibrary.simpleMessage("Status"),
    "connection_status_semantics": m16,
    "connection_switcher_title": MessageLookupByLibrary.simpleMessage("Switch connection"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Engine"),
    "connection_unstar": MessageLookupByLibrary.simpleMessage("Remove from favorites"),
    "connection_vanished": m17,
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("No internet connection"),
    "connectivity_offline_semantics": MessageLookupByLibrary.simpleMessage(
      "Offline: no internet connection. What is on screen was loaded earlier.",
    ),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Are you sure you want to delete?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Documentation"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editor_saved_text_discard": MessageLookupByLibrary.simpleMessage("Discard"),
    "editor_saved_text_discard_message": MessageLookupByLibrary.simpleMessage(
      "The saved text that cannot be read is deleted from this phone. This cannot be undone.",
    ),
    "editor_saved_text_discard_title": MessageLookupByLibrary.simpleMessage("Discard the saved text?"),
    "english": MessageLookupByLibrary.simpleMessage("English"),
    "error_auth_invalid_access_token": MessageLookupByLibrary.simpleMessage("Invalid access token"),
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
    "error_auth_session_persist_failed": MessageLookupByLibrary.simpleMessage("Could not save the session"),
    "error_editor_saved_text_not_stored": MessageLookupByLibrary.simpleMessage(
      "This phone could not save the statement text. Check its free storage and try again.",
    ),
    "error_editor_saved_text_unreadable": MessageLookupByLibrary.simpleMessage(
      "The statement text saved on this phone cannot be read. It may have come from a backup of another device, or the file was changed. Discard it to keep new text again.",
    ),
    "error_generic": MessageLookupByLibrary.simpleMessage("Something went wrong"),
    "error_link_open_failed": m18,
    "error_network_cert_invalid": MessageLookupByLibrary.simpleMessage(
      "The connection could not be verified as secure, so it was blocked. Try again later or on another network.",
    ),
    "error_network_offline": MessageLookupByLibrary.simpleMessage(
      "No internet connection. Check your network and try again.",
    ),
    "error_settings_change_language_failed": MessageLookupByLibrary.simpleMessage("Could not change the language"),
    "error_studio_account_has_no_identity": MessageLookupByLibrary.simpleMessage(
      "Studio cannot tell who this account is. Ask an administrator to check the account\'s email and username.",
    ),
    "error_studio_account_has_no_role": MessageLookupByLibrary.simpleMessage(
      "This account has no role in Studio. Ask an administrator to give it one.",
    ),
    "error_studio_account_refused": MessageLookupByLibrary.simpleMessage(
      "Studio did not accept this sign-in. Try again, or ask an administrator for access.",
    ),
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
    "force_update_versions": m19,
    "help_resources": MessageLookupByLibrary.simpleMessage("Help & Resources"),
    "help_resources_subtitle": MessageLookupByLibrary.simpleMessage("Read the documentation and guides on GitHub"),
    "home": MessageLookupByLibrary.simpleMessage("Home"),
    "idle_timeout_signed_out": MessageLookupByLibrary.simpleMessage("You were signed out due to inactivity."),
    "inactive": MessageLookupByLibrary.simpleMessage("Inactive"),
    "keys_browse": MessageLookupByLibrary.simpleMessage("Browse keys"),
    "keys_cap": MessageLookupByLibrary.simpleMessage(
      "This screen holds at most 10,000 keys: narrow the pattern to see the others.",
    ),
    "keys_clustered": MessageLookupByLibrary.simpleMessage(
      "Clustered server: SCAN and DBSIZE answer for one node at a time, so these counts are this node\'s.",
    ),
    "keys_empty": MessageLookupByLibrary.simpleMessage("Studio found no keys here."),
    "keys_listed": m20,
    "keys_listed_more": m21,
    "keys_load_all": MessageLookupByLibrary.simpleMessage("Load all"),
    "keys_load_more": MessageLookupByLibrary.simpleMessage("Load more"),
    "keys_pattern_glob": MessageLookupByLibrary.simpleMessage("Pattern"),
    "keys_pattern_prefix": MessageLookupByLibrary.simpleMessage("Starts with"),
    "keys_read_incomplete": m22,
    "keys_read_unknown": m23,
    "keys_scanned": m24,
    "keys_scanned_more": m25,
    "keys_scanned_of_database": m26,
    "keys_scanned_of_database_more": m27,
    "keys_scanned_of_walk": m28,
    "keys_scanned_of_walk_more": m29,
    "keys_skipped": m30,
    "keys_stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "keys_stopping": MessageLookupByLibrary.simpleMessage("Stopping after this page"),
    "keys_title": MessageLookupByLibrary.simpleMessage("Keys"),
    "keys_unavailable": MessageLookupByLibrary.simpleMessage("Studio declares no key browser for this connection."),
    "keys_value_no_read": MessageLookupByLibrary.simpleMessage("The app has no read for this type."),
    "keys_value_overline": MessageLookupByLibrary.simpleMessage("Key"),
    "keys_value_read": MessageLookupByLibrary.simpleMessage("Read value"),
    "keys_value_type": m31,
    "keys_value_unavailable": MessageLookupByLibrary.simpleMessage(
      "Reading a key\'s value is not available for this engine.",
    ),
    "keys_value_vanished": MessageLookupByLibrary.simpleMessage("This key no longer exists. Pull to read it again."),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "language_select": MessageLookupByLibrary.simpleMessage("Select Language"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
    "local_filter_clear": MessageLookupByLibrary.simpleMessage("Clear filter"),
    "local_filter_hint": MessageLookupByLibrary.simpleMessage("Filter"),
    "local_filter_no_match": MessageLookupByLibrary.simpleMessage("Nothing matches the filter."),
    "login": MessageLookupByLibrary.simpleMessage("Login"),
    "login_brand_description": MessageLookupByLibrary.simpleMessage(
      "Reach the databases LibreDB Studio grants you, from your phone.",
    ),
    "login_brand_headline": MessageLookupByLibrary.simpleMessage("Your databases,\nin your pocket."),
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
    "login_sso_button": MessageLookupByLibrary.simpleMessage("Sign in with SSO"),
    "login_sso_subtitle": MessageLookupByLibrary.simpleMessage("Sign in with your organization account."),
    "login_switch_to_dark_mode": MessageLookupByLibrary.simpleMessage("Switch to dark mode"),
    "login_switch_to_light_mode": MessageLookupByLibrary.simpleMessage("Switch to light mode"),
    "login_welcome_title": MessageLookupByLibrary.simpleMessage("Welcome back"),
    "logout": MessageLookupByLibrary.simpleMessage("Logout"),
    "logout_stored_data_left": MessageLookupByLibrary.simpleMessage(
      "You were signed out, but some stored data could not be removed from this device.",
    ),
    "logout_sure": MessageLookupByLibrary.simpleMessage("Are you sure you want to logout?"),
    "maintenance_estimated_end": m32,
    "maintenance_message": MessageLookupByLibrary.simpleMessage(
      "We are performing scheduled maintenance. Please check back soon.",
    ),
    "maintenance_retry": MessageLookupByLibrary.simpleMessage("Try Again"),
    "maintenance_title": MessageLookupByLibrary.simpleMessage("Under Maintenance"),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "new_item": MessageLookupByLibrary.simpleMessage("New"),
    "next": MessageLookupByLibrary.simpleMessage("Next"),
    "no": MessageLookupByLibrary.simpleMessage("No"),
    "no_data": MessageLookupByLibrary.simpleMessage("No Data"),
    "not_found_message": MessageLookupByLibrary.simpleMessage("The page you requested could not be found."),
    "not_found_title": MessageLookupByLibrary.simpleMessage("Page Not Found"),
    "offline_action_unavailable": MessageLookupByLibrary.simpleMessage("Needs an internet connection"),
    "offline_stale_data": m33,
    "pick_connection_first": MessageLookupByLibrary.simpleMessage("Pick a connection first"),
    "pick_connection_first_description": MessageLookupByLibrary.simpleMessage(
      "Open a connection from the Connections tab to use this tab.",
    ),
    "previous": MessageLookupByLibrary.simpleMessage("Previous"),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profile_governed_by_platform": MessageLookupByLibrary.simpleMessage("Governed by LibreDB Platform"),
    "profile_role_admin": MessageLookupByLibrary.simpleMessage("Administrator"),
    "profile_role_user": MessageLookupByLibrary.simpleMessage("User"),
    "profile_unknown_user": MessageLookupByLibrary.simpleMessage("Unknown user"),
    "refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "required_field": MessageLookupByLibrary.simpleMessage("Required Field"),
    "result_affected_rows": m34,
    "result_card_id": m35,
    "result_copied": MessageLookupByLibrary.simpleMessage("Copied"),
    "result_copy_failed": m36,
    "result_copy_row": MessageLookupByLibrary.simpleMessage("Copy row as JSON"),
    "result_copy_value": MessageLookupByLibrary.simpleMessage("Copy value"),
    "result_empty": MessageLookupByLibrary.simpleMessage("Query returned no data"),
    "result_empty_bounded": MessageLookupByLibrary.simpleMessage(
      "No row is shown: the result was cut before its first row",
    ),
    "result_engine_reported": MessageLookupByLibrary.simpleMessage("The engine reported:"),
    "result_limited": MessageLookupByLibrary.simpleMessage("limited"),
    "result_limited_notice": MessageLookupByLibrary.simpleMessage(
      "Studio bounded this result. Anything beyond the bound is not in it.",
    ),
    "result_load_more": m37,
    "result_loading_more": m38,
    "result_masked_semantics": MessageLookupByLibrary.simpleMessage("Masked value"),
    "result_more_fields": m39,
    "result_order_notice": MessageLookupByLibrary.simpleMessage(
      "Without an ORDER BY the engine may return rows that repeat or are skipped between pages.",
    ),
    "result_rolled_back": MessageLookupByLibrary.simpleMessage(
      "This statement left a transaction open, and Studio rolled it back, so its changes were discarded.",
    ),
    "result_row_position": m40,
    "result_row_title": m41,
    "result_stats": m42,
    "result_view_cards": MessageLookupByLibrary.simpleMessage("Cards"),
    "result_view_table": MessageLookupByLibrary.simpleMessage("Table"),
    "result_warning_code": m43,
    "result_warning_fallback": MessageLookupByLibrary.simpleMessage("Warning"),
    "result_warning_line": m44,
    "result_warnings": m45,
    "retry": MessageLookupByLibrary.simpleMessage("Retry"),
    "role": MessageLookupByLibrary.simpleMessage("Role"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "settings_appearance": MessageLookupByLibrary.simpleMessage("Appearance"),
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
    "studio_error_retry_in": m46,
    "studio_error_semantics": m47,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("Statement copied"),
    "studio_governance_cannot_serve": MessageLookupByLibrary.simpleMessage(
      "Studio cannot serve connections right now. An administrator needs to check its governance setup.",
    ),
    "studio_governance_detail": m48,
    "studio_governance_temporarily_unavailable": MessageLookupByLibrary.simpleMessage(
      "Connection access is temporarily unavailable. The list updates by itself once it is back.",
    ),
    "studio_unreachable_host": m49,
    "studio_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio does not answer. Check your internet connection, then try again.",
    ),
    "studio_unreachable_title": MessageLookupByLibrary.simpleMessage("Can\'t reach Studio"),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "success": MessageLookupByLibrary.simpleMessage("Success"),
    "tab_browse": MessageLookupByLibrary.simpleMessage("Browse"),
    "tab_sql": MessageLookupByLibrary.simpleMessage("SQL"),
    "table_rows_listed": m50,
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
    "warning": MessageLookupByLibrary.simpleMessage("Warning"),
    "yes": MessageLookupByLibrary.simpleMessage("Yes"),
  };
}
