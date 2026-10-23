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

  static String m18(catalog, used) => "The server does not list the database ${catalog}, so the editor uses ${used}.";

  static String m19(catalog) => "The server does not list the database ${catalog}.";

  static String m20(url) => "Could not open ${url}";

  static String m21(count, formatted) =>
      "${Intl.plural(count, one: 'Found 1 matching key', other: 'Found ${formatted} matching keys')}";

  static String m22(count, formatted) =>
      "${Intl.plural(count, one: 'Found 1 matching key; more remain', other: 'Found ${formatted} matching keys; more remain')}";

  static String m23(count, formatted, total) =>
      "${Intl.plural(count, one: 'Found 1 matching key; the database holds ${total}', other: 'Found ${formatted} matching keys; the database holds ${total}')}";

  static String m24(count, formatted, total) =>
      "${Intl.plural(count, one: 'Found 1 matching key; the database holds ${total}; more remain', other: 'Found ${formatted} matching keys; the database holds ${total}; more remain')}";

  static String m25(count, total) => "Found ${count} of the ${total} keys this walk covers";

  static String m26(count, total) => "Found ${count} of the ${total} keys this walk covers; more remain";

  static String m27(count, formatted) =>
      "${Intl.plural(count, one: 'Listed 1 entry', other: 'Listed ${formatted} entries')}";

  static String m28(count, formatted) =>
      "${Intl.plural(count, one: 'Listed 1 entry; more remain', other: 'Listed ${formatted} entries; more remain')}";

  static String m29(reason) => "This list is incomplete, and the engine can show why: ${reason}";

  static String m30(reason) =>
      "This list is what the read saw. Whether it is everything cannot be established on this engine: ${reason}";

  static String m31(count, formatted) =>
      "${Intl.plural(count, one: 'Scanned 1 key', other: 'Scanned ${formatted} keys')}";

  static String m32(count, formatted) =>
      "${Intl.plural(count, one: 'Scanned 1 key; more remain', other: 'Scanned ${formatted} keys; more remain')}";

  static String m33(count, total) => "Scanned ${count} of the ${total} keys this database holds";

  static String m34(count, total) => "Scanned ${count} of the ${total} keys this database holds; more remain";

  static String m35(count, total) => "Scanned ${count} of the ${total} keys this walk covers";

  static String m36(count, total) => "Scanned ${count} of the ${total} keys this walk covers; more remain";

  static String m37(count, formatted, reason) =>
      "${Intl.plural(count, one: '1 key left out of this walk: ${reason}', other: '${formatted} keys left out of this walk: ${reason}')}";

  static String m38(type) => "Studio says this key\'s type is ${type}.";

  static String m39(time) => "Offline: showing what was loaded at ${time}";

  static String m40(count, rows) => "${Intl.plural(count, one: '1 row affected', other: '${rows} rows affected')}";

  static String m41(id) => "#${id}";

  static String m42(code) => "Could not copy (${code})";

  static String m43(count, rows) => "${Intl.plural(count, one: 'Load 1 more', other: 'Load ${rows} more')}";

  static String m44(count, rows) => "${Intl.plural(count, one: 'Loading 1 more…', other: 'Loading ${rows} more…')}";

  static String m45(count) => "${Intl.plural(count, one: '+1 more field', other: '+${count} more fields')}";

  static String m46(index, count) => "Row ${index} of ${count}";

  static String m47(index) => "Row ${index}";

  static String m48(count, rows, time) =>
      "${Intl.plural(count, one: '1 row, ${time} ms', other: '${rows} rows, ${time} ms')}";

  static String m49(code) => "Code ${code}";

  static String m50(code) => "Warning ${code}";

  static String m51(severity, message) => "${severity}: ${message}";

  static String m52(count) => "${Intl.plural(count, one: '1 warning', other: '${count} warnings')}";

  static String m53(label, catalog) => "${label}: ${catalog}";

  static String m54(reason) => "The text could not be saved on this phone. ${reason}";

  static String m55(reason) =>
      "The text saved for this connection could not be read, so new text is not kept. ${reason}";

  static String m56(language) => "Language: ${language}";

  static String m57(reason) =>
      "The language of this connection could not be read, so the text is not highlighted. ${reason}";

  static String m58(keyword) =>
      "This statement left a transaction open, and Studio rolled it back, so its changes were discarded. Add ${keyword} to keep them.";

  static String m59(time) => "Running for ${time}";

  static String m60(time) => "${time} ms";

  static String m61(count) => "${Intl.plural(count, one: '1 statement not run', other: '${count} statements not run')}";

  static String m62(keyword) =>
      "The script left a transaction open, and Studio rolled it back, so its changes were discarded. Add ${keyword} to keep them.";

  static String m63(number) => "Statement ${number}";

  static String m64(milliseconds) => "${milliseconds} ms";

  static String m65(count) => "${Intl.plural(count, one: '1 row', other: '${count} rows')}";

  static String m66(seconds) => "You can try again in ${seconds} s.";

  static String m67(message) => "Error: ${message}";

  static String m68(detail) => "Details: ${detail}";

  static String m69(host) => "Studio address: ${host}";

  static String m70(count) => "${Intl.plural(count, one: '1 row listed.', other: '${count} rows listed.')}";

  static String m71(name) => "Type \"${name}\" to confirm";

  static String m72(word, line) => "May change data: ${word} on line ${line}";

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
    "browse_open_in_editor": MessageLookupByLibrary.simpleMessage("Open in editor"),
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
    "editor_catalog_not_listed": m18,
    "editor_catalog_not_listed_none": m19,
    "editor_open_connection_unavailable": MessageLookupByLibrary.simpleMessage(
      "That connection is no longer available, so the statement was not opened.",
    ),
    "editor_replace_message": MessageLookupByLibrary.simpleMessage(
      "The new statement takes the place of the text in the editor. It does not run.",
    ),
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
    "error_link_open_failed": m20,
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
    "error_studio_statement_too_large": MessageLookupByLibrary.simpleMessage(
      "This statement is too large to run. Shorten it and try again.",
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
    "keys_found": m21,
    "keys_found_more": m22,
    "keys_found_of_database": m23,
    "keys_found_of_database_more": m24,
    "keys_found_of_walk": m25,
    "keys_found_of_walk_more": m26,
    "keys_listed": m27,
    "keys_listed_more": m28,
    "keys_load_all": MessageLookupByLibrary.simpleMessage("Load all"),
    "keys_load_more": MessageLookupByLibrary.simpleMessage("Load more"),
    "keys_pattern_glob": MessageLookupByLibrary.simpleMessage("Pattern"),
    "keys_pattern_prefix": MessageLookupByLibrary.simpleMessage("Starts with"),
    "keys_read_incomplete": m29,
    "keys_read_unknown": m30,
    "keys_scanned": m31,
    "keys_scanned_more": m32,
    "keys_scanned_of_database": m33,
    "keys_scanned_of_database_more": m34,
    "keys_scanned_of_walk": m35,
    "keys_scanned_of_walk_more": m36,
    "keys_skipped": m37,
    "keys_stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "keys_stopping": MessageLookupByLibrary.simpleMessage("Stopping after this page"),
    "keys_title": MessageLookupByLibrary.simpleMessage("Keys"),
    "keys_unavailable": MessageLookupByLibrary.simpleMessage("Studio declares no key browser for this connection."),
    "keys_value_no_read": MessageLookupByLibrary.simpleMessage("The app has no read for this type."),
    "keys_value_overline": MessageLookupByLibrary.simpleMessage("Key"),
    "keys_value_read": MessageLookupByLibrary.simpleMessage("Read value"),
    "keys_value_type": m38,
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
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "new_item": MessageLookupByLibrary.simpleMessage("New"),
    "next": MessageLookupByLibrary.simpleMessage("Next"),
    "no": MessageLookupByLibrary.simpleMessage("No"),
    "no_data": MessageLookupByLibrary.simpleMessage("No Data"),
    "not_found_message": MessageLookupByLibrary.simpleMessage("The page you requested could not be found."),
    "not_found_title": MessageLookupByLibrary.simpleMessage("Page Not Found"),
    "offline_action_unavailable": MessageLookupByLibrary.simpleMessage("Needs an internet connection"),
    "offline_stale_data": m39,
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
    "result_affected_rows": m40,
    "result_card_id": m41,
    "result_copied": MessageLookupByLibrary.simpleMessage("Copied"),
    "result_copy_failed": m42,
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
    "result_load_more": m43,
    "result_loading_more": m44,
    "result_masked_semantics": MessageLookupByLibrary.simpleMessage("Masked value"),
    "result_more_fields": m45,
    "result_order_notice": MessageLookupByLibrary.simpleMessage(
      "Without an ORDER BY the engine may return rows that repeat or are skipped between pages.",
    ),
    "result_rolled_back": MessageLookupByLibrary.simpleMessage(
      "This statement left a transaction open, and Studio rolled it back, so its changes were discarded.",
    ),
    "result_row_position": m46,
    "result_row_title": m47,
    "result_stats": m48,
    "result_view_cards": MessageLookupByLibrary.simpleMessage("Cards"),
    "result_view_table": MessageLookupByLibrary.simpleMessage("Table"),
    "result_warning_code": m49,
    "result_warning_fallback": MessageLookupByLibrary.simpleMessage("Warning"),
    "result_warning_fallback_code": m50,
    "result_warning_line": m51,
    "result_warnings": m52,
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
    "sql_editor_cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "sql_editor_cancel_not_confirmed": MessageLookupByLibrary.simpleMessage(
      "Studio could not confirm the cancel. The statement may still run on the server.",
    ),
    "sql_editor_cancelled": MessageLookupByLibrary.simpleMessage("Cancelled"),
    "sql_editor_cancelling": MessageLookupByLibrary.simpleMessage("Cancelling"),
    "sql_editor_catalog_chip": m53,
    "sql_editor_catalog_failed": MessageLookupByLibrary.simpleMessage(
      "The databases to run statements in could not be listed.",
    ),
    "sql_editor_catalog_label": MessageLookupByLibrary.simpleMessage("Database"),
    "sql_editor_catalog_none": MessageLookupByLibrary.simpleMessage(
      "The server lists no database to run statements in.",
    ),
    "sql_editor_catalog_picker_title": MessageLookupByLibrary.simpleMessage("Run statements in"),
    "sql_editor_draft_no_account": MessageLookupByLibrary.simpleMessage(
      "Text is not kept until Studio names your account.",
    ),
    "sql_editor_draft_not_kept": MessageLookupByLibrary.simpleMessage(
      "This text is longer than 100,000 characters, so it is not kept on this phone, and the text saved earlier for this connection was removed.",
    ),
    "sql_editor_draft_not_saved": m54,
    "sql_editor_draft_read_failed": m55,
    "sql_editor_draft_unreadable_note": MessageLookupByLibrary.simpleMessage(
      "New text is not kept until you discard the saved text.",
    ),
    "sql_editor_field_label": MessageLookupByLibrary.simpleMessage("Statement"),
    "sql_editor_hint": MessageLookupByLibrary.simpleMessage("Type one or more statements"),
    "sql_editor_interrupted_read": MessageLookupByLibrary.simpleMessage(
      "The run was interrupted when the app went to the background; Studio cancelled it.",
    ),
    "sql_editor_interrupted_unknown": MessageLookupByLibrary.simpleMessage(
      "Outcome unknown: check the data before running it again.",
    ),
    "sql_editor_language": m56,
    "sql_editor_language_unknown": m57,
    "sql_editor_redo": MessageLookupByLibrary.simpleMessage("Redo"),
    "sql_editor_rolled_back": m58,
    "sql_editor_run": MessageLookupByLibrary.simpleMessage("Run"),
    "sql_editor_run_again": MessageLookupByLibrary.simpleMessage("Run again"),
    "sql_editor_run_selection": MessageLookupByLibrary.simpleMessage("Run selection"),
    "sql_editor_script_elapsed": m59,
    "sql_editor_script_failed": MessageLookupByLibrary.simpleMessage("Failed"),
    "sql_editor_script_failed_time": m60,
    "sql_editor_script_not_run": m61,
    "sql_editor_script_rolled_back": MessageLookupByLibrary.simpleMessage(
      "The script left a transaction open, and Studio rolled it back, so its changes were discarded.",
    ),
    "sql_editor_script_rolled_back_keep": m62,
    "sql_editor_script_show_rows": MessageLookupByLibrary.simpleMessage("Show rows"),
    "sql_editor_script_statement": m63,
    "sql_editor_script_succeeded": MessageLookupByLibrary.simpleMessage("Succeeded"),
    "sql_editor_stop_waiting": MessageLookupByLibrary.simpleMessage("Stop waiting"),
    "sql_editor_stopped_waiting": MessageLookupByLibrary.simpleMessage(
      "Stopped waiting. This database cannot cancel a statement, so it may still run on the server.",
    ),
    "sql_editor_tab": MessageLookupByLibrary.simpleMessage("Tab"),
    "sql_editor_undo": MessageLookupByLibrary.simpleMessage("Undo"),
    "sql_history_all_connections": MessageLookupByLibrary.simpleMessage("All connections"),
    "sql_history_clear_all": MessageLookupByLibrary.simpleMessage("Clear all"),
    "sql_history_clear_message": MessageLookupByLibrary.simpleMessage(
      "Every statement in your history on this phone is deleted. This cannot be undone.",
    ),
    "sql_history_clear_title": MessageLookupByLibrary.simpleMessage("Clear the history?"),
    "sql_history_delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "sql_history_duration": m64,
    "sql_history_empty": MessageLookupByLibrary.simpleMessage("No statements yet"),
    "sql_history_empty_description": MessageLookupByLibrary.simpleMessage(
      "Statements you run appear here. They stay on this phone.",
    ),
    "sql_history_failed": MessageLookupByLibrary.simpleMessage("Failed"),
    "sql_history_filter_all": MessageLookupByLibrary.simpleMessage("All"),
    "sql_history_filter_failure": MessageLookupByLibrary.simpleMessage("Failed"),
    "sql_history_filter_success": MessageLookupByLibrary.simpleMessage("Succeeded"),
    "sql_history_open": MessageLookupByLibrary.simpleMessage("History"),
    "sql_history_replace": MessageLookupByLibrary.simpleMessage("Replace"),
    "sql_history_replace_title": MessageLookupByLibrary.simpleMessage("Replace the editor\'s text?"),
    "sql_history_rows": m65,
    "sql_history_search_hint": MessageLookupByLibrary.simpleMessage("Search statements and connections"),
    "sql_history_succeeded": MessageLookupByLibrary.simpleMessage("Succeeded"),
    "sql_history_title": MessageLookupByLibrary.simpleMessage("History"),
    "sql_history_too_long": MessageLookupByLibrary.simpleMessage("Too long to keep"),
    "studio_error_copy_statement": MessageLookupByLibrary.simpleMessage("Copy statement"),
    "studio_error_fix_statement": MessageLookupByLibrary.simpleMessage(
      "An administrator can run this statement to fix it:",
    ),
    "studio_error_retry_in": m66,
    "studio_error_semantics": m67,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("Statement copied"),
    "studio_governance_cannot_serve": MessageLookupByLibrary.simpleMessage(
      "Studio cannot serve connections right now. An administrator needs to check its governance setup.",
    ),
    "studio_governance_detail": m68,
    "studio_governance_temporarily_unavailable": MessageLookupByLibrary.simpleMessage(
      "Connection access is temporarily unavailable. The list updates by itself once it is back.",
    ),
    "studio_unreachable_host": m69,
    "studio_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio does not answer. Check your internet connection, then try again.",
    ),
    "studio_unreachable_title": MessageLookupByLibrary.simpleMessage("Can\'t reach Studio"),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "success": MessageLookupByLibrary.simpleMessage("Success"),
    "tab_browse": MessageLookupByLibrary.simpleMessage("Browse"),
    "tab_sql": MessageLookupByLibrary.simpleMessage("SQL"),
    "table_rows_listed": m70,
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
    "write_confirm_cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "write_confirm_name_label": m71,
    "write_confirm_no_name": MessageLookupByLibrary.simpleMessage(
      "This production connection has no name to type, so the statement cannot be confirmed here.",
    ),
    "write_confirm_production_prompt": MessageLookupByLibrary.simpleMessage(
      "This is a production connection. Type its name to run the statement.",
    ),
    "write_confirm_read_grant": MessageLookupByLibrary.simpleMessage(
      "Your access to this connection is read only, so Studio will refuse a write here. An administrator can raise it.",
    ),
    "write_confirm_read_only_connection": MessageLookupByLibrary.simpleMessage(
      "This connection is set read only by its operator, so Studio or the database will refuse a write here.",
    ),
    "write_confirm_reason_may_write": MessageLookupByLibrary.simpleMessage(
      "May change data: the app cannot tell how the statement starts",
    ),
    "write_confirm_reason_may_write_at": m72,
    "write_confirm_reason_not_sql": MessageLookupByLibrary.simpleMessage(
      "The app cannot read what a command of this engine does",
    ),
    "write_confirm_reason_several": MessageLookupByLibrary.simpleMessage("Runs more than one statement"),
    "write_confirm_run": MessageLookupByLibrary.simpleMessage("Run"),
    "write_confirm_text_heading": MessageLookupByLibrary.simpleMessage("What will run"),
    "write_confirm_title": MessageLookupByLibrary.simpleMessage("Confirm before running"),
    "yes": MessageLookupByLibrary.simpleMessage("Yes"),
  };
}
