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

  static String m0(mode) => "${mode} applied";

  static String m1(code) => "Could not count the rows (${code})";

  static String m2(reason) => "Could not count the rows: ${reason}";

  static String m3(value) => "Default: ${value}";

  static String m4(code) => "Could not check which tables these keys open (${code})";

  static String m5(reason) => "Could not check which tables these keys open: ${reason}";

  static String m6(table, column) => "References ${table}.${column}";

  static String m7(type) => "${type} (sampled)";

  static String m8(parent) => "On ${parent}";

  static String m9(count, formatted) => "${Intl.plural(count, one: '1 row', other: '${formatted} rows')}";

  static String m10(count, formatted) => "${Intl.plural(count, one: '1 object', other: '${formatted} objects')}";

  static String m11(matched, total) => "${matched} of ${total} match";

  static String m12(count) => "Type at least ${count} characters to search.";

  static String m13(term) => "No object\'s name holds \"${term}\".";

  static String m14(code) => "Could not copy (${code})";

  static String m15(code) => "Could not share (${code})";

  static String m16(reason) => "Could not share: ${reason}";

  static String m17(reason) => "The shared file stays on this phone until you sign out: ${reason}";

  static String m18(reason) => "Truncated: ${reason}";

  static String m19(latency) => "Reachable, ${latency} ms";

  static String m20(label) => "Environment: ${label}";

  static String m21(status) => "Status: ${status}";

  static String m22(name) => "${name} is no longer available";

  static String m23(catalog, used) => "The server does not list the database ${catalog}, so the editor uses ${used}.";

  static String m24(catalog) => "The server does not list the database ${catalog}.";

  static String m25(url) => "Could not open ${url}";

  static String m26(count, formatted) =>
      "${Intl.plural(count, one: 'Found 1 matching key', other: 'Found ${formatted} matching keys')}";

  static String m27(count, formatted) =>
      "${Intl.plural(count, one: 'Found 1 matching key; more remain', other: 'Found ${formatted} matching keys; more remain')}";

  static String m28(count, formatted, total) =>
      "${Intl.plural(count, one: 'Found 1 matching key; the database holds ${total}', other: 'Found ${formatted} matching keys; the database holds ${total}')}";

  static String m29(count, formatted, total) =>
      "${Intl.plural(count, one: 'Found 1 matching key; the database holds ${total}; more remain', other: 'Found ${formatted} matching keys; the database holds ${total}; more remain')}";

  static String m30(count, total) => "Found ${count} of the ${total} keys this walk covers";

  static String m31(count, total) => "Found ${count} of the ${total} keys this walk covers; more remain";

  static String m32(count, formatted) =>
      "${Intl.plural(count, one: 'Listed 1 entry', other: 'Listed ${formatted} entries')}";

  static String m33(count, formatted) =>
      "${Intl.plural(count, one: 'Listed 1 entry; more remain', other: 'Listed ${formatted} entries; more remain')}";

  static String m34(reason) => "This list is incomplete, and the engine can show why: ${reason}";

  static String m35(reason) =>
      "This list is what the read saw. Whether it is everything cannot be established on this engine: ${reason}";

  static String m36(count, formatted) =>
      "${Intl.plural(count, one: 'Scanned 1 key', other: 'Scanned ${formatted} keys')}";

  static String m37(count, formatted) =>
      "${Intl.plural(count, one: 'Scanned 1 key; more remain', other: 'Scanned ${formatted} keys; more remain')}";

  static String m38(count, total) => "Scanned ${count} of the ${total} keys this database holds";

  static String m39(count, total) => "Scanned ${count} of the ${total} keys this database holds; more remain";

  static String m40(count, total) => "Scanned ${count} of the ${total} keys this walk covers";

  static String m41(count, total) => "Scanned ${count} of the ${total} keys this walk covers; more remain";

  static String m42(count, formatted, reason) =>
      "${Intl.plural(count, one: '1 key left out of this walk: ${reason}', other: '${formatted} keys left out of this walk: ${reason}')}";

  static String m43(type) => "Studio says this key\'s type is ${type}.";

  static String m44(time) => "Offline: showing what was loaded at ${time}";

  static String m45(listings) => "LibreDB is listed on ${listings} official vendor and project sites.";

  static String m46(index, total) => "Panel ${index} of ${total}";

  static String m47(engines, channels) => "${engines} database engines, published on ${channels} channels";

  static String m48(connection) => "Connection: ${connection}";

  static String m49(date) => "From ${date}";

  static String m50(text) => "Text: ${text}";

  static String m51(value) => "Source: ${value}";

  static String m52(value) => "Type: ${value}";

  static String m53(value) => "Status: ${value}";

  static String m54(date) => "To ${date}";

  static String m55(user) => "User: ${user}";

  static String m56(ms) => "${ms} ms";

  static String m57(count) => "Rows: ${count}";

  static String m58(count) => "${count} h ago";

  static String m59(count) => "${count} min ago";

  static String m60(connection) =>
      "${connection} closes for every Studio user within about 30 seconds. Queries already running are not stopped. Its grants are kept.";

  static String m61(connection) =>
      "${connection} opens again for everyone who holds a grant on it. Those grants can take user seats of the license.";

  static String m62(date) => "Expires on ${date}";

  static String m63(connection) => "Change access to ${connection}";

  static String m64(connection) => "Give access to ${connection}";

  static String m65(date) => "Expired ${date}";

  static String m66(date) => "Expires ${date}";

  static String m67(name, date) => "Granted by ${name}, ${date}";

  static String m68(username, level, connection) => "${username} will lose ${level} access to ${connection}.";

  static String m69(host) => "Platform address: ${host}";

  static String m70(count, rows) => "${Intl.plural(count, one: '1 row affected', other: '${rows} rows affected')}";

  static String m71(id) => "#${id}";

  static String m72(code) => "Could not copy (${code})";

  static String m73(count, rows) => "${Intl.plural(count, one: 'Load 1 more', other: 'Load ${rows} more')}";

  static String m74(count, rows) => "${Intl.plural(count, one: 'Loading 1 more…', other: 'Loading ${rows} more…')}";

  static String m75(count) => "${Intl.plural(count, one: '+1 more field', other: '+${count} more fields')}";

  static String m76(index, count) => "Row ${index} of ${count}";

  static String m77(index) => "Row ${index}";

  static String m78(count, rows, time) =>
      "${Intl.plural(count, one: '1 row, ${time} ms', other: '${rows} rows, ${time} ms')}";

  static String m79(code) => "Code ${code}";

  static String m80(code) => "Warning ${code}";

  static String m81(severity, message) => "${severity}: ${message}";

  static String m82(count) => "${Intl.plural(count, one: '1 warning', other: '${count} warnings')}";

  static String m83(label, catalog) => "${label}: ${catalog}";

  static String m84(reason) => "The text could not be saved on this phone. ${reason}";

  static String m85(reason) =>
      "The text saved for this connection could not be read, so new text is not kept. ${reason}";

  static String m86(language) => "Language: ${language}";

  static String m87(reason) =>
      "The language of this connection could not be read, so the text is not highlighted. ${reason}";

  static String m88(keyword) =>
      "This statement left a transaction open, and Studio rolled it back, so its changes were discarded. Add ${keyword} to keep them.";

  static String m89(time) => "Running for ${time}";

  static String m90(time) => "${time} ms";

  static String m91(count) => "${Intl.plural(count, one: '1 statement not run', other: '${count} statements not run')}";

  static String m92(keyword) =>
      "The script left a transaction open, and Studio rolled it back, so its changes were discarded. Add ${keyword} to keep them.";

  static String m93(number) => "Statement ${number}";

  static String m94(milliseconds) => "${milliseconds} ms";

  static String m95(count) => "${Intl.plural(count, one: '1 row', other: '${count} rows')}";

  static String m96(seconds) => "You can try again in ${seconds} s.";

  static String m97(message) => "Error: ${message}";

  static String m98(detail) => "Details: ${detail}";

  static String m99(host) => "Studio address: ${host}";

  static String m100(count) => "${Intl.plural(count, one: '1 row listed.', other: '${count} rows listed.')}";

  static String m101(palette) => "${palette} theme applied";

  static String m102(name) => "Type \"${name}\" to confirm";

  static String m103(word, line) => "May change data: ${word} on line ${line}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "account_refusal_title": MessageLookupByLibrary.simpleMessage("Your account has no access to Studio"),
    "active": MessageLookupByLibrary.simpleMessage("Active"),
    "admin": MessageLookupByLibrary.simpleMessage("Admin"),
    "app_lock": MessageLookupByLibrary.simpleMessage("App lock"),
    "app_lock_check_failed": MessageLookupByLibrary.simpleMessage(
      "LibreDB could not check this device\'s screen lock. Try Unlock again, or sign out.",
    ),
    "app_lock_enable_reason": MessageLookupByLibrary.simpleMessage("Confirm it is you to turn on the app lock"),
    "app_lock_failed": MessageLookupByLibrary.simpleMessage("Not recognized. Try again."),
    "app_lock_locked_message": MessageLookupByLibrary.simpleMessage("Unlock with your screen lock to continue."),
    "app_lock_locked_message_face": MessageLookupByLibrary.simpleMessage(
      "Unlock with your face or screen lock to continue.",
    ),
    "app_lock_locked_message_fingerprint": MessageLookupByLibrary.simpleMessage(
      "Unlock with your fingerprint or screen lock to continue.",
    ),
    "app_lock_locked_message_iris": MessageLookupByLibrary.simpleMessage(
      "Unlock with your iris or screen lock to continue.",
    ),
    "app_lock_locked_message_several": MessageLookupByLibrary.simpleMessage(
      "Unlock with your biometrics or screen lock to continue.",
    ),
    "app_lock_locked_out": MessageLookupByLibrary.simpleMessage("Too many attempts. Try again later."),
    "app_lock_locked_title": MessageLookupByLibrary.simpleMessage("LibreDB is locked"),
    "app_lock_no_screen_lock": MessageLookupByLibrary.simpleMessage(
      "Set a screen lock on this device to use LibreDB, or sign out.",
    ),
    "app_lock_no_screen_lock_subtitle": MessageLookupByLibrary.simpleMessage(
      "Set a screen lock on this device to turn this on",
    ),
    "app_lock_prompt_reason": MessageLookupByLibrary.simpleMessage("Unlock LibreDB"),
    "app_lock_required_subtitle": MessageLookupByLibrary.simpleMessage("Required by your organization"),
    "app_lock_subtitle": MessageLookupByLibrary.simpleMessage(
      "Ask for your fingerprint, face or screen lock when the app opens",
    ),
    "app_lock_timeout": MessageLookupByLibrary.simpleMessage("Lock after"),
    "app_lock_timeout_fifteen_minutes": MessageLookupByLibrary.simpleMessage("15 minutes in the background"),
    "app_lock_timeout_five_minutes": MessageLookupByLibrary.simpleMessage("5 minutes in the background"),
    "app_lock_timeout_immediately": MessageLookupByLibrary.simpleMessage("Immediately"),
    "app_lock_timeout_one_minute": MessageLookupByLibrary.simpleMessage("1 minute in the background"),
    "app_lock_unlock": MessageLookupByLibrary.simpleMessage("Unlock"),
    "app_title": MessageLookupByLibrary.simpleMessage("LibreDB"),
    "apply": MessageLookupByLibrary.simpleMessage("Apply"),
    "brightness": MessageLookupByLibrary.simpleMessage("Day and night"),
    "brightness_applied": m0,
    "brightness_dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "brightness_dark_description": MessageLookupByLibrary.simpleMessage("Always dark, whatever the phone is set to"),
    "brightness_dialog_subtitle": MessageLookupByLibrary.simpleMessage(
      "Choose light, dark, or whatever the phone is set to",
    ),
    "brightness_dialog_title": MessageLookupByLibrary.simpleMessage("Day and night"),
    "brightness_light": MessageLookupByLibrary.simpleMessage("Light"),
    "brightness_light_description": MessageLookupByLibrary.simpleMessage("Always light, whatever the phone is set to"),
    "brightness_system": MessageLookupByLibrary.simpleMessage("Follow the phone"),
    "brightness_system_description": MessageLookupByLibrary.simpleMessage(
      "Light or dark, as the phone\'s own setting says",
    ),
    "browse_count_failed": m1,
    "browse_count_failed_reason": m2,
    "browse_count_rows": MessageLookupByLibrary.simpleMessage("Count rows"),
    "browse_detail_columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "browse_detail_default": m3,
    "browse_detail_exclusion_constraints": MessageLookupByLibrary.simpleMessage("Exclusion constraints"),
    "browse_detail_foreign_keys": MessageLookupByLibrary.simpleMessage("Foreign keys"),
    "browse_detail_indexes": MessageLookupByLibrary.simpleMessage("Indexes"),
    "browse_detail_links_unchecked": m4,
    "browse_detail_links_unchecked_reason": m5,
    "browse_detail_no_columns": MessageLookupByLibrary.simpleMessage("Studio lists no columns."),
    "browse_detail_no_foreign_keys": MessageLookupByLibrary.simpleMessage("Studio lists no foreign keys."),
    "browse_detail_no_indexes": MessageLookupByLibrary.simpleMessage("Studio lists no indexes."),
    "browse_detail_nullable": MessageLookupByLibrary.simpleMessage("Nullable"),
    "browse_detail_primary_key": MessageLookupByLibrary.simpleMessage("Primary key"),
    "browse_detail_references": m6,
    "browse_detail_sampled": MessageLookupByLibrary.simpleMessage("Columns inferred from sampled documents"),
    "browse_detail_sampled_type": m7,
    "browse_detail_unique": MessageLookupByLibrary.simpleMessage("Unique"),
    "browse_details": MessageLookupByLibrary.simpleMessage("Details"),
    "browse_kinds_empty": MessageLookupByLibrary.simpleMessage("Studio counts no objects here."),
    "browse_level_empty": MessageLookupByLibrary.simpleMessage("Studio lists nothing at this level."),
    "browse_object_attached_to": m8,
    "browse_object_copy_name": MessageLookupByLibrary.simpleMessage("Copy name"),
    "browse_object_name_copied": MessageLookupByLibrary.simpleMessage("Name copied"),
    "browse_object_rows": m9,
    "browse_object_status_disabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "browse_object_status_invalid": MessageLookupByLibrary.simpleMessage("Invalid"),
    "browse_object_view_source": MessageLookupByLibrary.simpleMessage("View source"),
    "browse_objects": MessageLookupByLibrary.simpleMessage("Objects"),
    "browse_objects_count": m10,
    "browse_objects_empty": MessageLookupByLibrary.simpleMessage("Studio lists no objects of this kind here."),
    "browse_objects_match": m11,
    "browse_open_in_editor": MessageLookupByLibrary.simpleMessage("Open in editor"),
    "browse_preview_unavailable": MessageLookupByLibrary.simpleMessage("Preview is not available for this engine yet"),
    "browse_rows_database_says": MessageLookupByLibrary.simpleMessage("The database says"),
    "browse_search_action": MessageLookupByLibrary.simpleMessage("Search objects"),
    "browse_search_clear": MessageLookupByLibrary.simpleMessage("Clear search"),
    "browse_search_hint": MessageLookupByLibrary.simpleMessage("Search by name"),
    "browse_search_min_length": m12,
    "browse_search_no_results": m13,
    "browse_search_not_available": MessageLookupByLibrary.simpleMessage(
      "Search is not available on this connection; browse instead",
    ),
    "browse_search_title": MessageLookupByLibrary.simpleMessage("Search"),
    "browse_source": MessageLookupByLibrary.simpleMessage("Source"),
    "browse_source_copied": MessageLookupByLibrary.simpleMessage("Copied"),
    "browse_source_copy": MessageLookupByLibrary.simpleMessage("Copy all"),
    "browse_source_copy_failed": m14,
    "browse_source_partial": MessageLookupByLibrary.simpleMessage("Partial"),
    "browse_source_regenerated": MessageLookupByLibrary.simpleMessage("Regenerated by Studio, not the stored text"),
    "browse_source_share": MessageLookupByLibrary.simpleMessage("Share"),
    "browse_source_share_failed": m15,
    "browse_source_share_failed_reason": m16,
    "browse_source_share_file_left": m17,
    "browse_source_truncated": m18,
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
    "connection_check_online": m19,
    "connection_check_online_no_latency": MessageLookupByLibrary.simpleMessage("Reachable"),
    "connection_database": MessageLookupByLibrary.simpleMessage("Database"),
    "connection_environment": MessageLookupByLibrary.simpleMessage("Environment"),
    "connection_environment_badge": m20,
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
    "connection_status_semantics": m21,
    "connection_switcher_title": MessageLookupByLibrary.simpleMessage("Switch connection"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Engine"),
    "connection_unstar": MessageLookupByLibrary.simpleMessage("Remove from favorites"),
    "connection_vanished": m22,
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("No internet connection"),
    "connectivity_offline_semantics": MessageLookupByLibrary.simpleMessage(
      "Offline: no internet connection. What is on screen was loaded earlier.",
    ),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Are you sure you want to delete?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Documentation"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editor_catalog_not_listed": m23,
    "editor_catalog_not_listed_none": m24,
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
      "This build has no sign-in settings. Ask whoever gave you the app for a complete build.",
    ),
    "error_auth_oidc_discovery": MessageLookupByLibrary.simpleMessage(
      "The identity provider could not be reached. Try again later, or contact your administrator if this continues.",
    ),
    "error_auth_oidc_failed": MessageLookupByLibrary.simpleMessage("Sign-in failed. Please try again."),
    "error_auth_oidc_logout_incomplete": MessageLookupByLibrary.simpleMessage(
      "You are signed out of this app, but your session at the identity provider may still be active.",
    ),
    "error_auth_session_persist_failed": MessageLookupByLibrary.simpleMessage("Could not save the session"),
    "error_auth_share_files_not_removed": MessageLookupByLibrary.simpleMessage(
      "Files shared on this phone earlier could not be removed, so you are not signed in. Try again.",
    ),
    "error_browse_rows_interrupted": MessageLookupByLibrary.simpleMessage(
      "Reading the rows was interrupted when the app went to the background; Studio cancelled it.",
    ),
    "error_editor_page_interrupted": MessageLookupByLibrary.simpleMessage(
      "Loading more was interrupted when the app went to the background; Studio cancelled it.",
    ),
    "error_editor_page_outcome_unknown": MessageLookupByLibrary.simpleMessage(
      "Loading more was interrupted in the background, and its outcome is unknown: each page runs the whole statement again, so check the data before running it again.",
    ),
    "error_editor_saved_text_not_stored": MessageLookupByLibrary.simpleMessage(
      "This phone could not save the statement text. Check its free storage and try again.",
    ),
    "error_editor_saved_text_unreadable": MessageLookupByLibrary.simpleMessage(
      "The statement text saved on this phone cannot be read. It may have come from a backup of another device, or the file was changed. Discard it to keep new text again.",
    ),
    "error_generic": MessageLookupByLibrary.simpleMessage("Something went wrong"),
    "error_link_open_failed": m25,
    "error_network_cert_invalid": MessageLookupByLibrary.simpleMessage(
      "The connection could not be verified as secure, so it was blocked. Try again later or on another network.",
    ),
    "error_network_offline": MessageLookupByLibrary.simpleMessage(
      "No internet connection. Check your network and try again.",
    ),
    "error_platform_account_refused": MessageLookupByLibrary.simpleMessage(
      "Platform did not accept this sign-in. Ask an administrator to check that this app is set up for Platform, or sign in to Studio.",
    ),
    "error_platform_admin_role_required": MessageLookupByLibrary.simpleMessage(
      "This account is not a Platform admin. Sign in through Studio instead.",
    ),
    "error_platform_api_disabled": MessageLookupByLibrary.simpleMessage(
      "This Platform install does not accept the mobile app.",
    ),
    "error_platform_directory_unavailable": MessageLookupByLibrary.simpleMessage(
      "Platform cannot read the user directory right now. Try again in a moment.",
    ),
    "error_platform_grant_expiry_refused": MessageLookupByLibrary.simpleMessage("The expiry must be in the future."),
    "error_platform_grant_level_refused": MessageLookupByLibrary.simpleMessage(
      "Write access needs a connection with a write credential.",
    ),
    "error_platform_grant_subject_refused": MessageLookupByLibrary.simpleMessage(
      "Keycloak does not know this user, or has disabled it.",
    ),
    "error_platform_identity_provider_unavailable": MessageLookupByLibrary.simpleMessage(
      "Platform cannot reach the identity provider right now. Try again in a moment.",
    ),
    "error_platform_internal_error": MessageLookupByLibrary.simpleMessage(
      "Platform could not complete the request. Try again later.",
    ),
    "error_platform_keycloak_unavailable": MessageLookupByLibrary.simpleMessage(
      "Platform cannot reach Keycloak right now. Try again in a moment.",
    ),
    "error_platform_license_admin_seats": MessageLookupByLibrary.simpleMessage(
      "The Platform license has no free admin seat for this account.",
    ),
    "error_platform_license_expired": MessageLookupByLibrary.simpleMessage("The Platform license has expired."),
    "error_platform_license_invalid": MessageLookupByLibrary.simpleMessage("The Platform license is not valid."),
    "error_platform_license_user_seats": MessageLookupByLibrary.simpleMessage(
      "The Platform license has no free user seat for this grant.",
    ),
    "error_platform_not_configured": MessageLookupByLibrary.simpleMessage(
      "Platform mode is not available in this build of the app. Sign in through Studio.",
    ),
    "error_platform_not_found": MessageLookupByLibrary.simpleMessage("Platform no longer has this item."),
    "error_platform_permission_denied": MessageLookupByLibrary.simpleMessage(
      "Platform does not allow this account to do this.",
    ),
    "error_platform_plan_feature_required": MessageLookupByLibrary.simpleMessage(
      "The plan of this Platform install does not include this feature.",
    ),
    "error_platform_unreachable": MessageLookupByLibrary.simpleMessage(
      "Platform does not answer. Try again in a moment.",
    ),
    "error_platform_unreadable_answer": MessageLookupByLibrary.simpleMessage(
      "Platform sent an answer this app cannot read. The app may need an update.",
    ),
    "error_platform_validation_failed": MessageLookupByLibrary.simpleMessage("Platform did not accept the request."),
    "error_settings_app_lock_not_saved": MessageLookupByLibrary.simpleMessage(
      "The app lock setting could not be saved.",
    ),
    "error_settings_change_language_failed": MessageLookupByLibrary.simpleMessage("Could not change the language"),
    "error_settings_user_data_not_removed": MessageLookupByLibrary.simpleMessage(
      "Some of your data could not be removed from this phone, so you are still signed in.",
    ),
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
    "error_studio_search_pair_limit": MessageLookupByLibrary.simpleMessage(
      "Too many places to search. Pick object kinds to narrow the search.",
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
    "error_studio_unreachable": MessageLookupByLibrary.simpleMessage("Studio does not answer. Try again in a moment."),
    "error_studio_unreadable_answer": MessageLookupByLibrary.simpleMessage(
      "Studio sent an answer this app cannot read. The app or Studio may need an update.",
    ),
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
    "keys_found": m26,
    "keys_found_more": m27,
    "keys_found_of_database": m28,
    "keys_found_of_database_more": m29,
    "keys_found_of_walk": m30,
    "keys_found_of_walk_more": m31,
    "keys_listed": m32,
    "keys_listed_more": m33,
    "keys_load_all": MessageLookupByLibrary.simpleMessage("Load all"),
    "keys_load_more": MessageLookupByLibrary.simpleMessage("Load more"),
    "keys_pattern_glob": MessageLookupByLibrary.simpleMessage("Pattern"),
    "keys_pattern_prefix": MessageLookupByLibrary.simpleMessage("Starts with"),
    "keys_read_incomplete": m34,
    "keys_read_unknown": m35,
    "keys_scanned": m36,
    "keys_scanned_more": m37,
    "keys_scanned_of_database": m38,
    "keys_scanned_of_database_more": m39,
    "keys_scanned_of_walk": m40,
    "keys_scanned_of_walk_more": m41,
    "keys_skipped": m42,
    "keys_stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "keys_stopping": MessageLookupByLibrary.simpleMessage("Stopping after this page"),
    "keys_title": MessageLookupByLibrary.simpleMessage("Keys"),
    "keys_unavailable": MessageLookupByLibrary.simpleMessage("Studio declares no key browser for this connection."),
    "keys_value_no_read": MessageLookupByLibrary.simpleMessage("The app has no read for this type."),
    "keys_value_overline": MessageLookupByLibrary.simpleMessage("Key"),
    "keys_value_read": MessageLookupByLibrary.simpleMessage("Read value"),
    "keys_value_type": m43,
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
    "login_platform_button": MessageLookupByLibrary.simpleMessage("Sign in to Platform"),
    "login_platform_helper": MessageLookupByLibrary.simpleMessage(
      "For Platform admins. Your first Platform sign-in takes one admin seat of the license.",
    ),
    "login_sso_button": MessageLookupByLibrary.simpleMessage("Sign in with SSO"),
    "login_sso_subtitle": MessageLookupByLibrary.simpleMessage("Sign in with your organization account."),
    "login_studio_button": MessageLookupByLibrary.simpleMessage("Sign in to Studio"),
    "login_studio_helper": MessageLookupByLibrary.simpleMessage("Browse and query the databases Studio grants you."),
    "login_switch_to_dark_mode": MessageLookupByLibrary.simpleMessage("Switch to dark mode"),
    "login_switch_to_light_mode": MessageLookupByLibrary.simpleMessage("Switch to light mode"),
    "login_unreachable_platform": MessageLookupByLibrary.simpleMessage("Platform does not answer."),
    "login_unreachable_studio": MessageLookupByLibrary.simpleMessage("Studio does not answer."),
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
    "offline_stale_data": m44,
    "onboarding_done": MessageLookupByLibrary.simpleMessage("Get started"),
    "onboarding_listings_body": m45,
    "onboarding_listings_title": MessageLookupByLibrary.simpleMessage("Where you already look"),
    "onboarding_mobile_body": MessageLookupByLibrary.simpleMessage(
      "Browse the databases you have been granted, read a table, run a statement and see the answer, from your phone.",
    ),
    "onboarding_mobile_title": MessageLookupByLibrary.simpleMessage("This app is the window"),
    "onboarding_next": MessageLookupByLibrary.simpleMessage("Next"),
    "onboarding_panel_position": m46,
    "onboarding_platform_body": MessageLookupByLibrary.simpleMessage(
      "Platform owns the connections, decides who may reach which database, and keeps a record of every statement that runs.",
    ),
    "onboarding_platform_title": MessageLookupByLibrary.simpleMessage("LibreDB Platform governs"),
    "onboarding_skip": MessageLookupByLibrary.simpleMessage("Skip"),
    "onboarding_studio_body": MessageLookupByLibrary.simpleMessage(
      "Studio holds every credential and opens every connection. It runs what you ask against the databases Platform has granted you, and this app never sees a password.",
    ),
    "onboarding_studio_figures": m47,
    "onboarding_studio_title": MessageLookupByLibrary.simpleMessage("LibreDB Studio runs them"),
    "pick_connection_first": MessageLookupByLibrary.simpleMessage("Pick a connection first"),
    "pick_connection_first_description": MessageLookupByLibrary.simpleMessage(
      "Open a connection from the Connections tab to use this tab.",
    ),
    "platform_account_refusal_title": MessageLookupByLibrary.simpleMessage("LibreDB Platform refused your account"),
    "platform_audit_any": MessageLookupByLibrary.simpleMessage("Any"),
    "platform_audit_capture_full": MessageLookupByLibrary.simpleMessage("Full"),
    "platform_audit_capture_none": MessageLookupByLibrary.simpleMessage("None"),
    "platform_audit_capture_redacted": MessageLookupByLibrary.simpleMessage("Redacted"),
    "platform_audit_chip_connection": m48,
    "platform_audit_chip_from": m49,
    "platform_audit_chip_remove": MessageLookupByLibrary.simpleMessage("Remove this filter"),
    "platform_audit_chip_search": m50,
    "platform_audit_chip_source": m51,
    "platform_audit_chip_statement_type": m52,
    "platform_audit_chip_status": m53,
    "platform_audit_chip_to": m54,
    "platform_audit_chip_user": m55,
    "platform_audit_clear_filters": MessageLookupByLibrary.simpleMessage("Clear filters"),
    "platform_audit_duration": m56,
    "platform_audit_empty_description": MessageLookupByLibrary.simpleMessage(
      "Queries that Studio runs on Platform connections appear here.",
    ),
    "platform_audit_empty_title": MessageLookupByLibrary.simpleMessage("No governed queries yet"),
    "platform_audit_field_access_level": MessageLookupByLibrary.simpleMessage("Access level"),
    "platform_audit_field_capture": MessageLookupByLibrary.simpleMessage("Statement capture"),
    "platform_audit_field_connection": MessageLookupByLibrary.simpleMessage("Connection"),
    "platform_audit_field_connection_id": MessageLookupByLibrary.simpleMessage("Connection id"),
    "platform_audit_field_duration": MessageLookupByLibrary.simpleMessage("Duration"),
    "platform_audit_field_engine": MessageLookupByLibrary.simpleMessage("Engine"),
    "platform_audit_field_error_code": MessageLookupByLibrary.simpleMessage("Error code"),
    "platform_audit_field_error_message": MessageLookupByLibrary.simpleMessage("Error message"),
    "platform_audit_field_event_id": MessageLookupByLibrary.simpleMessage("Event id"),
    "platform_audit_field_explain": MessageLookupByLibrary.simpleMessage("Explain"),
    "platform_audit_field_finished": MessageLookupByLibrary.simpleMessage("Finished"),
    "platform_audit_field_rows": MessageLookupByLibrary.simpleMessage("Rows"),
    "platform_audit_field_session_role": MessageLookupByLibrary.simpleMessage("Session role"),
    "platform_audit_field_source": MessageLookupByLibrary.simpleMessage("Source"),
    "platform_audit_field_started": MessageLookupByLibrary.simpleMessage("Started"),
    "platform_audit_field_statement": MessageLookupByLibrary.simpleMessage("Statement"),
    "platform_audit_field_statement_type": MessageLookupByLibrary.simpleMessage("Statement type"),
    "platform_audit_field_status": MessageLookupByLibrary.simpleMessage("Status"),
    "platform_audit_field_subject": MessageLookupByLibrary.simpleMessage("Keycloak id"),
    "platform_audit_field_transaction": MessageLookupByLibrary.simpleMessage("Transaction outcome"),
    "platform_audit_field_user": MessageLookupByLibrary.simpleMessage("User"),
    "platform_audit_filter_any_day": MessageLookupByLibrary.simpleMessage("Any day"),
    "platform_audit_filter_clear_date": MessageLookupByLibrary.simpleMessage("Clear the date"),
    "platform_audit_filter_done": MessageLookupByLibrary.simpleMessage("Done"),
    "platform_audit_filter_from": MessageLookupByLibrary.simpleMessage("From"),
    "platform_audit_filter_search": MessageLookupByLibrary.simpleMessage("Statement text"),
    "platform_audit_filter_search_hint": MessageLookupByLibrary.simpleMessage("Text in the statement, any case"),
    "platform_audit_filter_source": MessageLookupByLibrary.simpleMessage("Source"),
    "platform_audit_filter_statement_type": MessageLookupByLibrary.simpleMessage("Statement type"),
    "platform_audit_filter_status": MessageLookupByLibrary.simpleMessage("Status"),
    "platform_audit_filter_to": MessageLookupByLibrary.simpleMessage("To"),
    "platform_audit_filtered_empty_description": MessageLookupByLibrary.simpleMessage(
      "Remove a filter or choose another one.",
    ),
    "platform_audit_filtered_empty_title": MessageLookupByLibrary.simpleMessage("No event matches the filters"),
    "platform_audit_filters": MessageLookupByLibrary.simpleMessage("Filters"),
    "platform_audit_load_failed": MessageLookupByLibrary.simpleMessage("Could not load the audit log"),
    "platform_audit_load_more": MessageLookupByLibrary.simpleMessage("Load more"),
    "platform_audit_load_more_failed": MessageLookupByLibrary.simpleMessage("Could not load more events"),
    "platform_audit_not_recorded": MessageLookupByLibrary.simpleMessage("Not recorded"),
    "platform_audit_only_this_connection": MessageLookupByLibrary.simpleMessage("Only this connection"),
    "platform_audit_only_this_user": MessageLookupByLibrary.simpleMessage("Only this user"),
    "platform_audit_permission_refused_description": MessageLookupByLibrary.simpleMessage(
      "A Platform admin can give this account the audit permission.",
    ),
    "platform_audit_permission_refused_title": MessageLookupByLibrary.simpleMessage(
      "Platform does not let this account read the audit log",
    ),
    "platform_audit_plan_refused_description": MessageLookupByLibrary.simpleMessage(
      "A plan with the audit log is chosen in the Platform license.",
    ),
    "platform_audit_plan_refused_title": MessageLookupByLibrary.simpleMessage(
      "The audit log is not in this install\'s plan",
    ),
    "platform_audit_refresh_failed": MessageLookupByLibrary.simpleMessage("Could not refresh the audit log"),
    "platform_audit_row_count": m57,
    "platform_audit_statement_none": MessageLookupByLibrary.simpleMessage("Not captured"),
    "platform_audit_statement_not_captured": MessageLookupByLibrary.simpleMessage("Statement not captured"),
    "platform_audit_statement_redacted": MessageLookupByLibrary.simpleMessage(
      "Redacted by the connection\'s capture setting",
    ),
    "platform_audit_statement_truncated": MessageLookupByLibrary.simpleMessage("Truncated by Studio"),
    "platform_audit_status_cancelled": MessageLookupByLibrary.simpleMessage("Cancelled"),
    "platform_audit_status_error": MessageLookupByLibrary.simpleMessage("Error"),
    "platform_audit_status_refused": MessageLookupByLibrary.simpleMessage("Refused"),
    "platform_audit_status_success": MessageLookupByLibrary.simpleMessage("Success"),
    "platform_audit_tab": MessageLookupByLibrary.simpleMessage("Audit"),
    "platform_audit_time_hours_ago": m58,
    "platform_audit_time_just_now": MessageLookupByLibrary.simpleMessage("Just now"),
    "platform_audit_time_minutes_ago": m59,
    "platform_audit_unknown_connection": MessageLookupByLibrary.simpleMessage("Unknown connection"),
    "platform_connections_active_actions": MessageLookupByLibrary.simpleMessage("Connection actions"),
    "platform_connections_active_disable": MessageLookupByLibrary.simpleMessage("Disable connection"),
    "platform_connections_active_disable_confirm": MessageLookupByLibrary.simpleMessage("Disable"),
    "platform_connections_active_disable_message": m60,
    "platform_connections_active_disabled": MessageLookupByLibrary.simpleMessage("Connection disabled"),
    "platform_connections_active_enable": MessageLookupByLibrary.simpleMessage("Enable connection"),
    "platform_connections_active_enable_confirm": MessageLookupByLibrary.simpleMessage("Enable"),
    "platform_connections_active_enable_message": m61,
    "platform_connections_active_enabled": MessageLookupByLibrary.simpleMessage("Connection enabled"),
    "platform_connections_active_gone": MessageLookupByLibrary.simpleMessage("This connection no longer exists"),
    "platform_connections_active_user_seats": MessageLookupByLibrary.simpleMessage(
      "The Platform license does not have enough user seats for the grants of this connection.",
    ),
    "platform_connections_active_user_seats_title": MessageLookupByLibrary.simpleMessage("Not enough user seats"),
    "platform_connections_empty_description": MessageLookupByLibrary.simpleMessage(
      "Connections are added in the Platform web console.",
    ),
    "platform_connections_empty_title": MessageLookupByLibrary.simpleMessage("This install has no connections yet"),
    "platform_connections_filter_hint": MessageLookupByLibrary.simpleMessage("Filter by name or engine"),
    "platform_connections_load_failed": MessageLookupByLibrary.simpleMessage("Could not load the connections"),
    "platform_connections_read_grants_only": MessageLookupByLibrary.simpleMessage("Read grants only"),
    "platform_connections_read_grants_only_semantics": MessageLookupByLibrary.simpleMessage(
      "This connection has no write credential, so only read access can be granted.",
    ),
    "platform_connections_refresh_failed": MessageLookupByLibrary.simpleMessage("Could not refresh the connections"),
    "platform_connections_search_empty_description": MessageLookupByLibrary.simpleMessage(
      "Try another name or engine.",
    ),
    "platform_connections_search_empty_title": MessageLookupByLibrary.simpleMessage("No connection matches the filter"),
    "platform_connections_status_unknown": MessageLookupByLibrary.simpleMessage("Unknown status"),
    "platform_grants_actions": MessageLookupByLibrary.simpleMessage("Grant actions"),
    "platform_grants_add": MessageLookupByLibrary.simpleMessage("Add access"),
    "platform_grants_already_removed": MessageLookupByLibrary.simpleMessage("Already removed"),
    "platform_grants_back_to_connections": MessageLookupByLibrary.simpleMessage("Back to connections"),
    "platform_grants_connection_gone_description": MessageLookupByLibrary.simpleMessage(
      "It may have been deleted in the Platform web console.",
    ),
    "platform_grants_connection_gone_title": MessageLookupByLibrary.simpleMessage("This connection no longer exists"),
    "platform_grants_edit": MessageLookupByLibrary.simpleMessage("Change access"),
    "platform_grants_editor_change_user": MessageLookupByLibrary.simpleMessage("Choose another user"),
    "platform_grants_editor_expiry": MessageLookupByLibrary.simpleMessage("Expiry"),
    "platform_grants_editor_expiry_local_time": MessageLookupByLibrary.simpleMessage("In this device\'s time zone."),
    "platform_grants_editor_expiry_never": MessageLookupByLibrary.simpleMessage("Never expires"),
    "platform_grants_editor_expiry_not_in_future": MessageLookupByLibrary.simpleMessage(
      "Choose a time in the future, or no expiry.",
    ),
    "platform_grants_editor_expiry_on": m62,
    "platform_grants_editor_expiry_pick": MessageLookupByLibrary.simpleMessage("Pick a date and time"),
    "platform_grants_editor_level": MessageLookupByLibrary.simpleMessage("Access level"),
    "platform_grants_editor_level_missing": MessageLookupByLibrary.simpleMessage("Choose an access level."),
    "platform_grants_editor_license_title": MessageLookupByLibrary.simpleMessage(
      "The license does not allow this grant",
    ),
    "platform_grants_editor_no_role_note": MessageLookupByLibrary.simpleMessage(
      "This user has no Studio role and cannot sign in to Studio until a Keycloak admin gives them one.",
    ),
    "platform_grants_editor_retry_title": MessageLookupByLibrary.simpleMessage("Platform could not check the user"),
    "platform_grants_editor_save": MessageLookupByLibrary.simpleMessage("Save"),
    "platform_grants_editor_saved": MessageLookupByLibrary.simpleMessage("Access saved"),
    "platform_grants_editor_title_edit": m63,
    "platform_grants_editor_title_new": m64,
    "platform_grants_editor_write_unavailable": MessageLookupByLibrary.simpleMessage(
      "This connection has no write credential, so only read access can be granted.",
    ),
    "platform_grants_empty_description": MessageLookupByLibrary.simpleMessage(
      "No one holds a grant on this connection.",
    ),
    "platform_grants_empty_title": MessageLookupByLibrary.simpleMessage("No one has access yet"),
    "platform_grants_expired": m65,
    "platform_grants_expires": m66,
    "platform_grants_granted_by": m67,
    "platform_grants_level_read": MessageLookupByLibrary.simpleMessage("Read"),
    "platform_grants_level_read_in_sentence": MessageLookupByLibrary.simpleMessage("read"),
    "platform_grants_level_write": MessageLookupByLibrary.simpleMessage("Write"),
    "platform_grants_level_write_in_sentence": MessageLookupByLibrary.simpleMessage("write"),
    "platform_grants_load_failed": MessageLookupByLibrary.simpleMessage("Could not load the grants"),
    "platform_grants_no_expiry": MessageLookupByLibrary.simpleMessage("No expiry"),
    "platform_grants_picker_clear": MessageLookupByLibrary.simpleMessage("Clear search"),
    "platform_grants_picker_disabled": MessageLookupByLibrary.simpleMessage("Disabled in Keycloak"),
    "platform_grants_picker_empty_description": MessageLookupByLibrary.simpleMessage(
      "No Keycloak user matches this search.",
    ),
    "platform_grants_picker_empty_title": MessageLookupByLibrary.simpleMessage("No user found"),
    "platform_grants_picker_load_failed": MessageLookupByLibrary.simpleMessage("Could not search the directory"),
    "platform_grants_picker_load_more": MessageLookupByLibrary.simpleMessage("Load more"),
    "platform_grants_picker_load_more_failed": MessageLookupByLibrary.simpleMessage("Could not load more users"),
    "platform_grants_picker_query_too_long": MessageLookupByLibrary.simpleMessage(
      "The search text is too long. Use at most 255 characters.",
    ),
    "platform_grants_picker_role_admin": MessageLookupByLibrary.simpleMessage("Studio admin"),
    "platform_grants_picker_role_none": MessageLookupByLibrary.simpleMessage(
      "No Studio role, cannot sign in to Studio",
    ),
    "platform_grants_picker_role_user": MessageLookupByLibrary.simpleMessage("Studio user"),
    "platform_grants_picker_search_hint": MessageLookupByLibrary.simpleMessage("Search by username, name or e-mail"),
    "platform_grants_picker_takes_seat": MessageLookupByLibrary.simpleMessage("Takes a user seat"),
    "platform_grants_picker_takes_seat_inactive": MessageLookupByLibrary.simpleMessage(
      "Takes a user seat when the connection is active again",
    ),
    "platform_grants_picker_title": MessageLookupByLibrary.simpleMessage("Choose a user"),
    "platform_grants_refresh_failed": MessageLookupByLibrary.simpleMessage("Could not refresh the grants"),
    "platform_grants_remove_access": MessageLookupByLibrary.simpleMessage("Remove access"),
    "platform_grants_remove_confirm": MessageLookupByLibrary.simpleMessage("Remove"),
    "platform_grants_remove_message": m68,
    "platform_grants_removed": MessageLookupByLibrary.simpleMessage("Access removed"),
    "platform_home_admin_label": MessageLookupByLibrary.simpleMessage("Platform admin"),
    "platform_home_connections_shortcut": MessageLookupByLibrary.simpleMessage("Connections"),
    "platform_home_connections_shortcut_description": MessageLookupByLibrary.simpleMessage(
      "See every connection of this install.",
    ),
    "platform_home_identity_load_failed": MessageLookupByLibrary.simpleMessage("Could not load your Platform account"),
    "platform_home_signed_in_as": MessageLookupByLibrary.simpleMessage("Signed in as"),
    "platform_home_tenant_label": MessageLookupByLibrary.simpleMessage("Organization"),
    "platform_status_unreachable_host": m69,
    "platform_status_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Platform does not answer. Check your internet connection, then try again.",
    ),
    "platform_status_unreachable_title": MessageLookupByLibrary.simpleMessage("Can\'t reach Platform"),
    "previous": MessageLookupByLibrary.simpleMessage("Previous"),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profile_governed_by_platform": MessageLookupByLibrary.simpleMessage("Governed by LibreDB Platform"),
    "profile_mode_platform": MessageLookupByLibrary.simpleMessage("Platform admin"),
    "profile_mode_studio": MessageLookupByLibrary.simpleMessage("Studio"),
    "profile_role_admin": MessageLookupByLibrary.simpleMessage("Administrator"),
    "profile_role_user": MessageLookupByLibrary.simpleMessage("User"),
    "profile_switch_admin_role_required": MessageLookupByLibrary.simpleMessage(
      "This account is not a Platform admin, so it stays in Studio.",
    ),
    "profile_switch_confirm": MessageLookupByLibrary.simpleMessage("Switch"),
    "profile_switch_platform_message": MessageLookupByLibrary.simpleMessage(
      "Platform mode is for Platform admins. The first time this account opens Platform, it takes one admin seat of the license.",
    ),
    "profile_switch_platform_refused": MessageLookupByLibrary.simpleMessage(
      "Platform did not accept this account, so it stays in Studio. Ask an administrator to check that this app is set up for Platform.",
    ),
    "profile_switch_platform_title": MessageLookupByLibrary.simpleMessage("Switch to Platform?"),
    "profile_switch_platform_unreachable": MessageLookupByLibrary.simpleMessage(
      "Platform does not answer, so this account stays in Studio. Try again in a moment.",
    ),
    "profile_switch_studio_refused": MessageLookupByLibrary.simpleMessage(
      "Studio did not accept this account, so it stays in Platform. Ask an administrator for access.",
    ),
    "profile_switch_studio_unreachable": MessageLookupByLibrary.simpleMessage(
      "Studio does not answer, so this account stays in Platform. Try again in a moment.",
    ),
    "profile_switch_to_platform": MessageLookupByLibrary.simpleMessage("Switch to Platform"),
    "profile_switch_to_studio": MessageLookupByLibrary.simpleMessage("Switch to Studio"),
    "profile_unknown_user": MessageLookupByLibrary.simpleMessage("Unknown user"),
    "refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "remove_my_data": MessageLookupByLibrary.simpleMessage("Remove my data"),
    "remove_my_data_collapsed_sections": MessageLookupByLibrary.simpleMessage(
      "Collapsed sections of the connection list",
    ),
    "remove_my_data_confirm": MessageLookupByLibrary.simpleMessage("Remove and sign out"),
    "remove_my_data_drafts": MessageLookupByLibrary.simpleMessage("SQL editor drafts"),
    "remove_my_data_favorites": MessageLookupByLibrary.simpleMessage("Starred connections"),
    "remove_my_data_history": MessageLookupByLibrary.simpleMessage("Statement history"),
    "remove_my_data_kept": MessageLookupByLibrary.simpleMessage("Kept on this phone"),
    "remove_my_data_kept_preferences": MessageLookupByLibrary.simpleMessage(
      "Language, theme, result view and app lock",
    ),
    "remove_my_data_last_connection": MessageLookupByLibrary.simpleMessage("The last open connection and database"),
    "remove_my_data_recents": MessageLookupByLibrary.simpleMessage("Recent connections"),
    "remove_my_data_removed": MessageLookupByLibrary.simpleMessage("Removed from this phone"),
    "remove_my_data_signs_out": MessageLookupByLibrary.simpleMessage("You are signed out once your data is removed."),
    "remove_my_data_subtitle": MessageLookupByLibrary.simpleMessage(
      "Remove what this app keeps about you on this phone, then sign out",
    ),
    "remove_my_data_title": MessageLookupByLibrary.simpleMessage("Remove my data?"),
    "required_field": MessageLookupByLibrary.simpleMessage("Required Field"),
    "result_affected_rows": m70,
    "result_card_id": m71,
    "result_copied": MessageLookupByLibrary.simpleMessage("Copied"),
    "result_copy_failed": m72,
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
    "result_load_more": m73,
    "result_loading_more": m74,
    "result_masked_semantics": MessageLookupByLibrary.simpleMessage("Masked value"),
    "result_more_fields": m75,
    "result_order_notice": MessageLookupByLibrary.simpleMessage(
      "Without an ORDER BY the engine may return rows that repeat or are skipped between pages.",
    ),
    "result_rolled_back": MessageLookupByLibrary.simpleMessage(
      "This statement left a transaction open, and Studio rolled it back, so its changes were discarded.",
    ),
    "result_row_position": m76,
    "result_row_title": m77,
    "result_stats": m78,
    "result_view_cards": MessageLookupByLibrary.simpleMessage("Cards"),
    "result_view_table": MessageLookupByLibrary.simpleMessage("Table"),
    "result_warning_code": m79,
    "result_warning_fallback": MessageLookupByLibrary.simpleMessage("Warning"),
    "result_warning_fallback_code": m80,
    "result_warning_line": m81,
    "result_warnings": m82,
    "retry": MessageLookupByLibrary.simpleMessage("Retry"),
    "role": MessageLookupByLibrary.simpleMessage("Role"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "settings_appearance": MessageLookupByLibrary.simpleMessage("Appearance"),
    "settings_licenses": MessageLookupByLibrary.simpleMessage("Licenses"),
    "settings_licenses_subtitle": MessageLookupByLibrary.simpleMessage(
      "The licenses of LibreDB Mobile and the code it includes",
    ),
    "settings_privacy": MessageLookupByLibrary.simpleMessage("Privacy"),
    "settings_security": MessageLookupByLibrary.simpleMessage("Security"),
    "settings_subtitle": MessageLookupByLibrary.simpleMessage("Manage your account preferences"),
    "settings_theme_subtitle": MessageLookupByLibrary.simpleMessage("Choose your preferred theme style"),
    "sql_editor_cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "sql_editor_cancel_not_confirmed": MessageLookupByLibrary.simpleMessage(
      "Studio could not confirm the cancel. The statement may still run on the server.",
    ),
    "sql_editor_cancelled": MessageLookupByLibrary.simpleMessage("Cancelled"),
    "sql_editor_cancelling": MessageLookupByLibrary.simpleMessage("Cancelling"),
    "sql_editor_catalog_chip": m83,
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
    "sql_editor_draft_not_saved": m84,
    "sql_editor_draft_read_failed": m85,
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
    "sql_editor_language": m86,
    "sql_editor_language_unknown": m87,
    "sql_editor_redo": MessageLookupByLibrary.simpleMessage("Redo"),
    "sql_editor_rolled_back": m88,
    "sql_editor_run": MessageLookupByLibrary.simpleMessage("Run"),
    "sql_editor_run_again": MessageLookupByLibrary.simpleMessage("Run again"),
    "sql_editor_run_selection": MessageLookupByLibrary.simpleMessage("Run selection"),
    "sql_editor_script_elapsed": m89,
    "sql_editor_script_failed": MessageLookupByLibrary.simpleMessage("Failed"),
    "sql_editor_script_failed_time": m90,
    "sql_editor_script_not_run": m91,
    "sql_editor_script_rolled_back": MessageLookupByLibrary.simpleMessage(
      "The script left a transaction open, and Studio rolled it back, so its changes were discarded.",
    ),
    "sql_editor_script_rolled_back_keep": m92,
    "sql_editor_script_show_rows": MessageLookupByLibrary.simpleMessage("Show rows"),
    "sql_editor_script_statement": m93,
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
    "sql_history_duration": m94,
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
    "sql_history_rows": m95,
    "sql_history_search_hint": MessageLookupByLibrary.simpleMessage("Search statements and connections"),
    "sql_history_succeeded": MessageLookupByLibrary.simpleMessage("Succeeded"),
    "sql_history_title": MessageLookupByLibrary.simpleMessage("History"),
    "sql_history_too_long": MessageLookupByLibrary.simpleMessage("Too long to keep"),
    "studio_error_copy_statement": MessageLookupByLibrary.simpleMessage("Copy statement"),
    "studio_error_fix_statement": MessageLookupByLibrary.simpleMessage(
      "An administrator can run this statement to fix it:",
    ),
    "studio_error_retry_in": m96,
    "studio_error_semantics": m97,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("Statement copied"),
    "studio_governance_cannot_serve": MessageLookupByLibrary.simpleMessage(
      "Studio cannot serve connections right now. An administrator needs to check its governance setup.",
    ),
    "studio_governance_detail": m98,
    "studio_governance_temporarily_unavailable": MessageLookupByLibrary.simpleMessage(
      "Connection access is temporarily unavailable. The list updates by itself once it is back.",
    ),
    "studio_unreachable_host": m99,
    "studio_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio does not answer. Check your internet connection, then try again.",
    ),
    "studio_unreachable_title": MessageLookupByLibrary.simpleMessage("Can\'t reach Studio"),
    "success": MessageLookupByLibrary.simpleMessage("Success"),
    "tab_browse": MessageLookupByLibrary.simpleMessage("Browse"),
    "tab_sql": MessageLookupByLibrary.simpleMessage("SQL"),
    "table_rows_listed": m100,
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "theme_dialog_subtitle": MessageLookupByLibrary.simpleMessage("Select your preferred theme style"),
    "theme_dialog_title": MessageLookupByLibrary.simpleMessage("Choose Theme"),
    "theme_palette_applied": m101,
    "theme_palette_classic": MessageLookupByLibrary.simpleMessage("Classic"),
    "theme_palette_classic_description": MessageLookupByLibrary.simpleMessage("Cool neutral, clean and minimal"),
    "theme_palette_nature": MessageLookupByLibrary.simpleMessage("Nature"),
    "theme_palette_nature_description": MessageLookupByLibrary.simpleMessage("Sage green, calm and organic"),
    "theme_palette_sunset": MessageLookupByLibrary.simpleMessage("Sunset"),
    "theme_palette_sunset_description": MessageLookupByLibrary.simpleMessage("Warm stone, rich and inviting"),
    "turkish": MessageLookupByLibrary.simpleMessage("Turkish"),
    "unsaved_changes": MessageLookupByLibrary.simpleMessage(
      "You have unsaved changes. Are you sure you want to leave?",
    ),
    "warning": MessageLookupByLibrary.simpleMessage("Warning"),
    "write_confirm_cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "write_confirm_name_label": m102,
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
    "write_confirm_reason_may_write_at": m103,
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
