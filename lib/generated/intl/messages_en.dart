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

  static String m0(reason) => "Administrator\'s reason: ${reason}";

  static String m1(date) => "Sent ${date}";

  static String m2(level, connection) =>
      "Your request for ${level} access to ${connection} will be withdrawn. You can ask again later.";

  static String m3(mode) => "${mode} applied";

  static String m4(code) => "Could not count the rows (${code})";

  static String m5(reason) => "Could not count the rows: ${reason}";

  static String m6(value) => "Default: ${value}";

  static String m7(code) => "Could not check which tables these keys open (${code})";

  static String m8(reason) => "Could not check which tables these keys open: ${reason}";

  static String m9(table, column) => "References ${table}.${column}";

  static String m10(type) => "${type} (sampled)";

  static String m11(parent) => "On ${parent}";

  static String m12(count, formatted) => "${Intl.plural(count, one: '1 row', other: '${formatted} rows')}";

  static String m13(count, formatted) => "${Intl.plural(count, one: '1 object', other: '${formatted} objects')}";

  static String m14(matched, total) => "${matched} of ${total} match";

  static String m15(count) => "Type at least ${count} characters to search.";

  static String m16(term) => "No object\'s name holds \"${term}\".";

  static String m17(code) => "Could not copy (${code})";

  static String m18(code) => "Could not share (${code})";

  static String m19(reason) => "Could not share: ${reason}";

  static String m20(reason) => "The shared file stays on this phone until you sign out: ${reason}";

  static String m21(reason) => "Truncated: ${reason}";

  static String m22(latency) => "Reachable, ${latency} ms";

  static String m23(label) => "Environment: ${label}";

  static String m24(status) => "Status: ${status}";

  static String m25(name) => "${name} is no longer available";

  static String m26(catalog, used) => "The server does not list the database ${catalog}, so the editor uses ${used}.";

  static String m27(catalog) => "The server does not list the database ${catalog}.";

  static String m28(url) => "Could not open ${url}";

  static String m29(count, formatted) =>
      "${Intl.plural(count, one: 'Found 1 matching key', other: 'Found ${formatted} matching keys')}";

  static String m30(count, formatted) =>
      "${Intl.plural(count, one: 'Found 1 matching key; more remain', other: 'Found ${formatted} matching keys; more remain')}";

  static String m31(count, formatted, total) =>
      "${Intl.plural(count, one: 'Found 1 matching key; the database holds ${total}', other: 'Found ${formatted} matching keys; the database holds ${total}')}";

  static String m32(count, formatted, total) =>
      "${Intl.plural(count, one: 'Found 1 matching key; the database holds ${total}; more remain', other: 'Found ${formatted} matching keys; the database holds ${total}; more remain')}";

  static String m33(count, total) => "Found ${count} of the ${total} keys this walk covers";

  static String m34(count, total) => "Found ${count} of the ${total} keys this walk covers; more remain";

  static String m35(count, formatted) =>
      "${Intl.plural(count, one: 'Listed 1 entry', other: 'Listed ${formatted} entries')}";

  static String m36(count, formatted) =>
      "${Intl.plural(count, one: 'Listed 1 entry; more remain', other: 'Listed ${formatted} entries; more remain')}";

  static String m37(reason) => "This list is incomplete, and the engine can show why: ${reason}";

  static String m38(reason) =>
      "This list is what the read saw. Whether it is everything cannot be established on this engine: ${reason}";

  static String m39(count, formatted) =>
      "${Intl.plural(count, one: 'Scanned 1 key', other: 'Scanned ${formatted} keys')}";

  static String m40(count, formatted) =>
      "${Intl.plural(count, one: 'Scanned 1 key; more remain', other: 'Scanned ${formatted} keys; more remain')}";

  static String m41(count, total) => "Scanned ${count} of the ${total} keys this database holds";

  static String m42(count, total) => "Scanned ${count} of the ${total} keys this database holds; more remain";

  static String m43(count, total) => "Scanned ${count} of the ${total} keys this walk covers";

  static String m44(count, total) => "Scanned ${count} of the ${total} keys this walk covers; more remain";

  static String m45(count, formatted, reason) =>
      "${Intl.plural(count, one: '1 key left out of this walk: ${reason}', other: '${formatted} keys left out of this walk: ${reason}')}";

  static String m46(type) => "Studio says this key\'s type is ${type}.";

  static String m47(line) => "Until someone grants you one, the list reads: \"${line}\"";

  static String m48(connection) => "${connection} · browse";

  static String m49(count) => "${Intl.plural(count, one: '1 table', other: '${count} tables')}";

  static String m50(connection) => "editor · ${connection}";

  static String m51(rows, duration) => "${rows} · ${duration}";

  static String m52(current, total) => "${current} / ${total}";

  static String m53(current, total) => "Step ${current} of ${total}";

  static String m54(time) => "Offline: showing what was loaded at ${time}";

  static String m55(listings) => "LibreDB is listed on ${listings} official vendor and project sites.";

  static String m56(index, total) => "Panel ${index} of ${total}";

  static String m57(engines, channels) => "${engines} database engines, published on ${channels} channels";

  static String m58(connection) => "Connection: ${connection}";

  static String m59(date) => "From ${date}";

  static String m60(text) => "Text: ${text}";

  static String m61(value) => "Source: ${value}";

  static String m62(value) => "Type: ${value}";

  static String m63(value) => "Status: ${value}";

  static String m64(date) => "To ${date}";

  static String m65(user) => "User: ${user}";

  static String m66(ms) => "${ms} ms";

  static String m67(count) => "Rows: ${count}";

  static String m68(count) => "${count} h ago";

  static String m69(count) => "${count} min ago";

  static String m70(connection) =>
      "${connection} closes for every Studio user within about 30 seconds. Queries already running are not stopped. Its grants are kept.";

  static String m71(connection) =>
      "${connection} opens again for everyone who holds a grant on it. Those grants can take user seats of the license.";

  static String m72(date) => "Expires on ${date}";

  static String m73(connection) => "Change access to ${connection}";

  static String m74(connection) => "Give access to ${connection}";

  static String m75(date) => "Expired ${date}";

  static String m76(date) => "Expires ${date}";

  static String m77(name, date) => "Granted by ${name}, ${date}";

  static String m78(username, level, connection) => "${username} will lose ${level} access to ${connection}.";

  static String m79(host) => "Platform address: ${host}";

  static String m80(count, rows) => "${Intl.plural(count, one: '1 row affected', other: '${rows} rows affected')}";

  static String m81(id) => "#${id}";

  static String m82(code) => "Could not copy (${code})";

  static String m83(count, rows) => "${Intl.plural(count, one: 'Load 1 more', other: 'Load ${rows} more')}";

  static String m84(count, rows) => "${Intl.plural(count, one: 'Loading 1 more…', other: 'Loading ${rows} more…')}";

  static String m85(count) => "${Intl.plural(count, one: '+1 more field', other: '+${count} more fields')}";

  static String m86(index, count) => "Row ${index} of ${count}";

  static String m87(index) => "Row ${index}";

  static String m88(count, rows, time) =>
      "${Intl.plural(count, one: '1 row, ${time} ms', other: '${rows} rows, ${time} ms')}";

  static String m89(code) => "Code ${code}";

  static String m90(code) => "Warning ${code}";

  static String m91(severity, message) => "${severity}: ${message}";

  static String m92(count) => "${Intl.plural(count, one: '1 warning', other: '${count} warnings')}";

  static String m93(label, catalog) => "${label}: ${catalog}";

  static String m94(reason) => "The text could not be saved on this phone. ${reason}";

  static String m95(reason) =>
      "The text saved for this connection could not be read, so new text is not kept. ${reason}";

  static String m96(language) => "Language: ${language}";

  static String m97(reason) =>
      "The language of this connection could not be read, so the text is not highlighted. ${reason}";

  static String m98(keyword) =>
      "This statement left a transaction open, and Studio rolled it back, so its changes were discarded. Add ${keyword} to keep them.";

  static String m99(time) => "Running for ${time}";

  static String m100(time) => "${time} ms";

  static String m101(count) =>
      "${Intl.plural(count, one: '1 statement not run', other: '${count} statements not run')}";

  static String m102(keyword) =>
      "The script left a transaction open, and Studio rolled it back, so its changes were discarded. Add ${keyword} to keep them.";

  static String m103(number) => "Statement ${number}";

  static String m104(milliseconds) => "${milliseconds} ms";

  static String m105(count) => "${Intl.plural(count, one: '1 row', other: '${count} rows')}";

  static String m106(seconds) => "You can try again in ${seconds} s.";

  static String m107(message) => "Error: ${message}";

  static String m108(detail) => "Details: ${detail}";

  static String m109(host) => "Studio address: ${host}";

  static String m110(count) => "${Intl.plural(count, one: '1 row listed.', other: '${count} rows listed.')}";

  static String m111(palette) => "${palette} theme applied";

  static String m112(name) => "Type \"${name}\" to confirm";

  static String m113(word, line) => "May change data: ${word} on line ${line}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "access_requests_approved_note": MessageLookupByLibrary.simpleMessage(
      "The connection appears in your connection list after you refresh it. It can take a moment.",
    ),
    "access_requests_empty_action": MessageLookupByLibrary.simpleMessage("Request access"),
    "access_requests_empty_description": MessageLookupByLibrary.simpleMessage(
      "Ask for access to a connection and follow the answer here.",
    ),
    "access_requests_empty_title": MessageLookupByLibrary.simpleMessage("No requests yet"),
    "access_requests_form_connection": MessageLookupByLibrary.simpleMessage("Connection"),
    "access_requests_form_connection_granted": MessageLookupByLibrary.simpleMessage("You already have access"),
    "access_requests_form_connection_pending": MessageLookupByLibrary.simpleMessage(
      "You already have a pending request",
    ),
    "access_requests_form_connection_required": MessageLookupByLibrary.simpleMessage("Choose a connection."),
    "access_requests_form_level": MessageLookupByLibrary.simpleMessage("Access level"),
    "access_requests_form_level_read_held": MessageLookupByLibrary.simpleMessage(
      "You already have read access to this connection.",
    ),
    "access_requests_form_level_required": MessageLookupByLibrary.simpleMessage("Choose an access level."),
    "access_requests_form_level_write_unavailable": MessageLookupByLibrary.simpleMessage(
      "This connection has no write credential, so write access cannot be requested.",
    ),
    "access_requests_form_load_failed": MessageLookupByLibrary.simpleMessage("The connections could not be loaded"),
    "access_requests_form_no_connections": MessageLookupByLibrary.simpleMessage(
      "There is no connection you can ask for right now.",
    ),
    "access_requests_form_reason": MessageLookupByLibrary.simpleMessage("Reason"),
    "access_requests_form_reason_hint": MessageLookupByLibrary.simpleMessage("Why do you need this access?"),
    "access_requests_form_reason_invalid": MessageLookupByLibrary.simpleMessage(
      "Write a reason of 1 to 500 characters.",
    ),
    "access_requests_form_send": MessageLookupByLibrary.simpleMessage("Send request"),
    "access_requests_level_read": MessageLookupByLibrary.simpleMessage("Read"),
    "access_requests_level_read_in_sentence": MessageLookupByLibrary.simpleMessage("read"),
    "access_requests_level_write": MessageLookupByLibrary.simpleMessage("Write"),
    "access_requests_level_write_in_sentence": MessageLookupByLibrary.simpleMessage("write"),
    "access_requests_load_failed": MessageLookupByLibrary.simpleMessage("Your requests could not be loaded"),
    "access_requests_new_title": MessageLookupByLibrary.simpleMessage("Request access"),
    "access_requests_profile_tile": MessageLookupByLibrary.simpleMessage("Access requests"),
    "access_requests_refused_no_reason": MessageLookupByLibrary.simpleMessage("The administrator gave no reason."),
    "access_requests_refused_reason": m0,
    "access_requests_sent_at": m1,
    "access_requests_sent_snackbar": MessageLookupByLibrary.simpleMessage("Request sent."),
    "access_requests_status_approved": MessageLookupByLibrary.simpleMessage("Approved"),
    "access_requests_status_pending": MessageLookupByLibrary.simpleMessage("Pending"),
    "access_requests_status_refused": MessageLookupByLibrary.simpleMessage("Refused"),
    "access_requests_status_withdrawn": MessageLookupByLibrary.simpleMessage("Withdrawn"),
    "access_requests_title": MessageLookupByLibrary.simpleMessage("My requests"),
    "access_requests_withdraw": MessageLookupByLibrary.simpleMessage("Withdraw"),
    "access_requests_withdraw_message": m2,
    "access_requests_withdraw_title": MessageLookupByLibrary.simpleMessage("Withdraw request"),
    "access_requests_withdrawn_snackbar": MessageLookupByLibrary.simpleMessage("Request withdrawn."),
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
    "brightness_applied": m3,
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
    "browse_count_failed": m4,
    "browse_count_failed_reason": m5,
    "browse_count_rows": MessageLookupByLibrary.simpleMessage("Count rows"),
    "browse_detail_columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "browse_detail_default": m6,
    "browse_detail_exclusion_constraints": MessageLookupByLibrary.simpleMessage("Exclusion constraints"),
    "browse_detail_foreign_keys": MessageLookupByLibrary.simpleMessage("Foreign keys"),
    "browse_detail_indexes": MessageLookupByLibrary.simpleMessage("Indexes"),
    "browse_detail_links_unchecked": m7,
    "browse_detail_links_unchecked_reason": m8,
    "browse_detail_no_columns": MessageLookupByLibrary.simpleMessage("Studio lists no columns."),
    "browse_detail_no_foreign_keys": MessageLookupByLibrary.simpleMessage("Studio lists no foreign keys."),
    "browse_detail_no_indexes": MessageLookupByLibrary.simpleMessage("Studio lists no indexes."),
    "browse_detail_nullable": MessageLookupByLibrary.simpleMessage("Nullable"),
    "browse_detail_primary_key": MessageLookupByLibrary.simpleMessage("Primary key"),
    "browse_detail_references": m9,
    "browse_detail_sampled": MessageLookupByLibrary.simpleMessage("Columns inferred from sampled documents"),
    "browse_detail_sampled_type": m10,
    "browse_detail_unique": MessageLookupByLibrary.simpleMessage("Unique"),
    "browse_details": MessageLookupByLibrary.simpleMessage("Details"),
    "browse_kinds_empty": MessageLookupByLibrary.simpleMessage("Studio counts no objects here."),
    "browse_level_empty": MessageLookupByLibrary.simpleMessage("Studio lists nothing at this level."),
    "browse_object_attached_to": m11,
    "browse_object_copy_name": MessageLookupByLibrary.simpleMessage("Copy name"),
    "browse_object_name_copied": MessageLookupByLibrary.simpleMessage("Name copied"),
    "browse_object_rows": m12,
    "browse_object_status_disabled": MessageLookupByLibrary.simpleMessage("Disabled"),
    "browse_object_status_invalid": MessageLookupByLibrary.simpleMessage("Invalid"),
    "browse_object_view_source": MessageLookupByLibrary.simpleMessage("View source"),
    "browse_objects": MessageLookupByLibrary.simpleMessage("Objects"),
    "browse_objects_count": m13,
    "browse_objects_empty": MessageLookupByLibrary.simpleMessage("Studio lists no objects of this kind here."),
    "browse_objects_match": m14,
    "browse_open_in_editor": MessageLookupByLibrary.simpleMessage("Open in editor"),
    "browse_preview_unavailable": MessageLookupByLibrary.simpleMessage("Preview is not available for this engine yet"),
    "browse_rows_database_says": MessageLookupByLibrary.simpleMessage("The database says"),
    "browse_search_action": MessageLookupByLibrary.simpleMessage("Search objects"),
    "browse_search_clear": MessageLookupByLibrary.simpleMessage("Clear search"),
    "browse_search_hint": MessageLookupByLibrary.simpleMessage("Search by name"),
    "browse_search_min_length": m15,
    "browse_search_no_results": m16,
    "browse_search_not_available": MessageLookupByLibrary.simpleMessage(
      "Search is not available on this connection; browse instead",
    ),
    "browse_search_title": MessageLookupByLibrary.simpleMessage("Search"),
    "browse_source": MessageLookupByLibrary.simpleMessage("Source"),
    "browse_source_copied": MessageLookupByLibrary.simpleMessage("Copied"),
    "browse_source_copy": MessageLookupByLibrary.simpleMessage("Copy all"),
    "browse_source_copy_failed": m17,
    "browse_source_partial": MessageLookupByLibrary.simpleMessage("Partial"),
    "browse_source_regenerated": MessageLookupByLibrary.simpleMessage("Regenerated by Studio, not the stored text"),
    "browse_source_share": MessageLookupByLibrary.simpleMessage("Share"),
    "browse_source_share_failed": m18,
    "browse_source_share_failed_reason": m19,
    "browse_source_share_file_left": m20,
    "browse_source_truncated": m21,
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
    "connection_check_online": m22,
    "connection_check_online_no_latency": MessageLookupByLibrary.simpleMessage("Reachable"),
    "connection_database": MessageLookupByLibrary.simpleMessage("Database"),
    "connection_environment": MessageLookupByLibrary.simpleMessage("Environment"),
    "connection_environment_badge": m23,
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
    "connection_status_semantics": m24,
    "connection_switcher_title": MessageLookupByLibrary.simpleMessage("Switch connection"),
    "connection_type": MessageLookupByLibrary.simpleMessage("Engine"),
    "connection_unstar": MessageLookupByLibrary.simpleMessage("Remove from favorites"),
    "connection_vanished": m25,
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectivity_offline": MessageLookupByLibrary.simpleMessage("No internet connection"),
    "connectivity_offline_semantics": MessageLookupByLibrary.simpleMessage(
      "Offline: no internet connection. What is on screen was loaded earlier.",
    ),
    "delete_confirmation": MessageLookupByLibrary.simpleMessage("Are you sure you want to delete?"),
    "documentation": MessageLookupByLibrary.simpleMessage("Documentation"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editor_catalog_not_listed": m26,
    "editor_catalog_not_listed_none": m27,
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
    "error_link_open_failed": m28,
    "error_network_cert_invalid": MessageLookupByLibrary.simpleMessage(
      "The connection could not be verified as secure, so it was blocked. Try again later or on another network.",
    ),
    "error_network_offline": MessageLookupByLibrary.simpleMessage(
      "No internet connection. Check your network and try again.",
    ),
    "error_platform_access_already_granted": MessageLookupByLibrary.simpleMessage("You already have this access."),
    "error_platform_access_request_decided": MessageLookupByLibrary.simpleMessage(
      "This request was already answered or withdrawn.",
    ),
    "error_platform_access_request_limit": MessageLookupByLibrary.simpleMessage(
      "You have too many open requests. Wait for an answer or withdraw one.",
    ),
    "error_platform_access_request_pending": MessageLookupByLibrary.simpleMessage(
      "You already have an open request for this connection.",
    ),
    "error_platform_access_request_reason_refused": MessageLookupByLibrary.simpleMessage(
      "Write a reason of at most 500 characters.",
    ),
    "error_platform_access_requests_disabled": MessageLookupByLibrary.simpleMessage(
      "Access requests are turned off on this installation.",
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
    "error_platform_studio_role_required": MessageLookupByLibrary.simpleMessage(
      "Your account has no Studio role, so it cannot ask for access.",
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
    "keys_found": m29,
    "keys_found_more": m30,
    "keys_found_of_database": m31,
    "keys_found_of_database_more": m32,
    "keys_found_of_walk": m33,
    "keys_found_of_walk_more": m34,
    "keys_listed": m35,
    "keys_listed_more": m36,
    "keys_load_all": MessageLookupByLibrary.simpleMessage("Load all"),
    "keys_load_more": MessageLookupByLibrary.simpleMessage("Load more"),
    "keys_pattern_glob": MessageLookupByLibrary.simpleMessage("Pattern"),
    "keys_pattern_prefix": MessageLookupByLibrary.simpleMessage("Starts with"),
    "keys_read_incomplete": m37,
    "keys_read_unknown": m38,
    "keys_scanned": m39,
    "keys_scanned_more": m40,
    "keys_scanned_of_database": m41,
    "keys_scanned_of_database_more": m42,
    "keys_scanned_of_walk": m43,
    "keys_scanned_of_walk_more": m44,
    "keys_skipped": m45,
    "keys_stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "keys_stopping": MessageLookupByLibrary.simpleMessage("Stopping after this page"),
    "keys_title": MessageLookupByLibrary.simpleMessage("Keys"),
    "keys_unavailable": MessageLookupByLibrary.simpleMessage("Studio declares no key browser for this connection."),
    "keys_value_no_read": MessageLookupByLibrary.simpleMessage("The app has no read for this type."),
    "keys_value_overline": MessageLookupByLibrary.simpleMessage("Key"),
    "keys_value_read": MessageLookupByLibrary.simpleMessage("Read value"),
    "keys_value_type": m46,
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
    "ob1_accent": MessageLookupByLibrary.simpleMessage("been given"),
    "ob1_body": MessageLookupByLibrary.simpleMessage(
      "PROD, STAGING, DEV — the badge says which one you are on. The read-only ones are marked.",
    ),
    "ob1_cap": MessageLookupByLibrary.simpleMessage("your connections"),
    "ob1_empty": m47,
    "ob1_title": MessageLookupByLibrary.simpleMessage("The databases\nyou\'ve been given."),
    "ob2_accent": MessageLookupByLibrary.simpleMessage("masked"),
    "ob2_body": MessageLookupByLibrary.simpleMessage(
      "Schemas, tables, row counts. The rule is Studio\'s; the phone applies it.",
    ),
    "ob2_cap": m48,
    "ob2_tables": m49,
    "ob2_title": MessageLookupByLibrary.simpleMessage("Open it. Read it.\nSome columns are masked."),
    "ob2_why": MessageLookupByLibrary.simpleMessage("masked by column name —\nthere is no switch here to turn it off"),
    "ob3_accent": MessageLookupByLibrary.simpleMessage("try a delete"),
    "ob3_body": MessageLookupByLibrary.simpleMessage(
      "Anything that may change data asks first. On a production connection you type its name.",
    ),
    "ob3_cap": m50,
    "ob3_count": MessageLookupByLibrary.simpleMessage("count"),
    "ob3_meta": m51,
    "ob3_title": MessageLookupByLibrary.simpleMessage("Run it.\nThen try a delete."),
    "ob4_accent": MessageLookupByLibrary.simpleMessage("Studio"),
    "ob4_app": MessageLookupByLibrary.simpleMessage("This app"),
    "ob4_back": MessageLookupByLibrary.simpleMessage("rows come back to you — the password never does"),
    "ob4_body": MessageLookupByLibrary.simpleMessage(
      "No database password is on the phone — only a session that expires. With the app lock on, that session sits behind the lock too.",
    ),
    "ob4_cap": MessageLookupByLibrary.simpleMessage("where the password was"),
    "ob4_connects": MessageLookupByLibrary.simpleMessage("connects"),
    "ob4_studio": MessageLookupByLibrary.simpleMessage("LibreDB Studio"),
    "ob4_title": MessageLookupByLibrary.simpleMessage("Studio holds it.\nYou never do."),
    "ob4_vault": MessageLookupByLibrary.simpleMessage("the password stays here"),
    "ob5_accent": MessageLookupByLibrary.simpleMessage("to Platform"),
    "ob5_body": MessageLookupByLibrary.simpleMessage(
      "Keycloak knows you once. Your phone talks to a Studio. The connections, the grants and the log live in the Platform above them — the administrator\'s side.",
    ),
    "ob5_cap": MessageLookupByLibrary.simpleMessage("the ecosystem"),
    "ob5_hub": MessageLookupByLibrary.simpleMessage("LibreDB Platform"),
    "ob5_keycloak": MessageLookupByLibrary.simpleMessage("Keycloak"),
    "ob5_keycloak_note": MessageLookupByLibrary.simpleMessage("knows you once"),
    "ob5_mode_note": MessageLookupByLibrary.simpleMessage(
      "same session, no second sign-in — the first switch takes an admin seat",
    ),
    "ob5_role_audit": MessageLookupByLibrary.simpleMessage("Audit log"),
    "ob5_role_connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "ob5_role_grants": MessageLookupByLibrary.simpleMessage("Grants"),
    "ob5_title": MessageLookupByLibrary.simpleMessage("Studios connect\nto Platform."),
    "ob5_you": MessageLookupByLibrary.simpleMessage("your phone"),
    "ob6_accent": MessageLookupByLibrary.simpleMessage("Platform"),
    "ob6_body": MessageLookupByLibrary.simpleMessage(
      "Platform grants access, ends it and sets when it expires. The statement you ran is in this log too.",
    ),
    "ob6_bye": MessageLookupByLibrary.simpleMessage("On to the sign-in"),
    "ob6_bye_note": MessageLookupByLibrary.simpleMessage("The introduction ends here; the app opens through Keycloak."),
    "ob6_cap": MessageLookupByLibrary.simpleMessage("platform · access and record"),
    "ob6_title": MessageLookupByLibrary.simpleMessage("Platform decides\nwho may reach what."),
    "ob6_you": MessageLookupByLibrary.simpleMessage("you"),
    "ob_done": MessageLookupByLibrary.simpleMessage("Sign in"),
    "ob_next": MessageLookupByLibrary.simpleMessage("Next"),
    "ob_skip": MessageLookupByLibrary.simpleMessage("Skip"),
    "ob_step": m52,
    "ob_step_semantics": m53,
    "offline_action_unavailable": MessageLookupByLibrary.simpleMessage("Needs an internet connection"),
    "offline_stale_data": m54,
    "onboarding_done": MessageLookupByLibrary.simpleMessage("Get started"),
    "onboarding_listings_body": m55,
    "onboarding_listings_title": MessageLookupByLibrary.simpleMessage("Where you already look"),
    "onboarding_mobile_body": MessageLookupByLibrary.simpleMessage(
      "Browse the databases you have been granted, read a table, run a statement and see the answer, from your phone.",
    ),
    "onboarding_mobile_title": MessageLookupByLibrary.simpleMessage("This app is the window"),
    "onboarding_next": MessageLookupByLibrary.simpleMessage("Next"),
    "onboarding_panel_position": m56,
    "onboarding_platform_body": MessageLookupByLibrary.simpleMessage(
      "Platform owns the connections, decides who may reach which database, and keeps a record of every statement that runs.",
    ),
    "onboarding_platform_title": MessageLookupByLibrary.simpleMessage("LibreDB Platform governs"),
    "onboarding_skip": MessageLookupByLibrary.simpleMessage("Skip"),
    "onboarding_studio_body": MessageLookupByLibrary.simpleMessage(
      "Studio holds every credential and opens every connection. It runs what you ask against the databases Platform has granted you, and this app never sees a password.",
    ),
    "onboarding_studio_figures": m57,
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
    "platform_audit_chip_connection": m58,
    "platform_audit_chip_from": m59,
    "platform_audit_chip_remove": MessageLookupByLibrary.simpleMessage("Remove this filter"),
    "platform_audit_chip_search": m60,
    "platform_audit_chip_source": m61,
    "platform_audit_chip_statement_type": m62,
    "platform_audit_chip_status": m63,
    "platform_audit_chip_to": m64,
    "platform_audit_chip_user": m65,
    "platform_audit_clear_filters": MessageLookupByLibrary.simpleMessage("Clear filters"),
    "platform_audit_duration": m66,
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
    "platform_audit_row_count": m67,
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
    "platform_audit_time_hours_ago": m68,
    "platform_audit_time_just_now": MessageLookupByLibrary.simpleMessage("Just now"),
    "platform_audit_time_minutes_ago": m69,
    "platform_audit_unknown_connection": MessageLookupByLibrary.simpleMessage("Unknown connection"),
    "platform_connections_active_actions": MessageLookupByLibrary.simpleMessage("Connection actions"),
    "platform_connections_active_disable": MessageLookupByLibrary.simpleMessage("Disable connection"),
    "platform_connections_active_disable_confirm": MessageLookupByLibrary.simpleMessage("Disable"),
    "platform_connections_active_disable_message": m70,
    "platform_connections_active_disabled": MessageLookupByLibrary.simpleMessage("Connection disabled"),
    "platform_connections_active_enable": MessageLookupByLibrary.simpleMessage("Enable connection"),
    "platform_connections_active_enable_confirm": MessageLookupByLibrary.simpleMessage("Enable"),
    "platform_connections_active_enable_message": m71,
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
    "platform_grants_editor_expiry_on": m72,
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
    "platform_grants_editor_title_edit": m73,
    "platform_grants_editor_title_new": m74,
    "platform_grants_editor_write_unavailable": MessageLookupByLibrary.simpleMessage(
      "This connection has no write credential, so only read access can be granted.",
    ),
    "platform_grants_empty_description": MessageLookupByLibrary.simpleMessage(
      "No one holds a grant on this connection.",
    ),
    "platform_grants_empty_title": MessageLookupByLibrary.simpleMessage("No one has access yet"),
    "platform_grants_expired": m75,
    "platform_grants_expires": m76,
    "platform_grants_granted_by": m77,
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
    "platform_grants_remove_message": m78,
    "platform_grants_removed": MessageLookupByLibrary.simpleMessage("Access removed"),
    "platform_home_admin_label": MessageLookupByLibrary.simpleMessage("Platform admin"),
    "platform_home_connections_shortcut": MessageLookupByLibrary.simpleMessage("Connections"),
    "platform_home_connections_shortcut_description": MessageLookupByLibrary.simpleMessage(
      "See every connection of this install.",
    ),
    "platform_home_identity_load_failed": MessageLookupByLibrary.simpleMessage("Could not load your Platform account"),
    "platform_home_signed_in_as": MessageLookupByLibrary.simpleMessage("Signed in as"),
    "platform_home_tenant_label": MessageLookupByLibrary.simpleMessage("Organization"),
    "platform_status_unreachable_host": m79,
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
    "result_affected_rows": m80,
    "result_card_id": m81,
    "result_copied": MessageLookupByLibrary.simpleMessage("Copied"),
    "result_copy_failed": m82,
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
    "result_load_more": m83,
    "result_loading_more": m84,
    "result_masked_semantics": MessageLookupByLibrary.simpleMessage("Masked value"),
    "result_more_fields": m85,
    "result_order_notice": MessageLookupByLibrary.simpleMessage(
      "Without an ORDER BY the engine may return rows that repeat or are skipped between pages.",
    ),
    "result_rolled_back": MessageLookupByLibrary.simpleMessage(
      "This statement left a transaction open, and Studio rolled it back, so its changes were discarded.",
    ),
    "result_row_position": m86,
    "result_row_title": m87,
    "result_stats": m88,
    "result_view_cards": MessageLookupByLibrary.simpleMessage("Cards"),
    "result_view_table": MessageLookupByLibrary.simpleMessage("Table"),
    "result_warning_code": m89,
    "result_warning_fallback": MessageLookupByLibrary.simpleMessage("Warning"),
    "result_warning_fallback_code": m90,
    "result_warning_line": m91,
    "result_warnings": m92,
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
    "sql_editor_catalog_chip": m93,
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
    "sql_editor_draft_not_saved": m94,
    "sql_editor_draft_read_failed": m95,
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
    "sql_editor_language": m96,
    "sql_editor_language_unknown": m97,
    "sql_editor_redo": MessageLookupByLibrary.simpleMessage("Redo"),
    "sql_editor_rolled_back": m98,
    "sql_editor_run": MessageLookupByLibrary.simpleMessage("Run"),
    "sql_editor_run_again": MessageLookupByLibrary.simpleMessage("Run again"),
    "sql_editor_run_selection": MessageLookupByLibrary.simpleMessage("Run selection"),
    "sql_editor_script_elapsed": m99,
    "sql_editor_script_failed": MessageLookupByLibrary.simpleMessage("Failed"),
    "sql_editor_script_failed_time": m100,
    "sql_editor_script_not_run": m101,
    "sql_editor_script_rolled_back": MessageLookupByLibrary.simpleMessage(
      "The script left a transaction open, and Studio rolled it back, so its changes were discarded.",
    ),
    "sql_editor_script_rolled_back_keep": m102,
    "sql_editor_script_show_rows": MessageLookupByLibrary.simpleMessage("Show rows"),
    "sql_editor_script_statement": m103,
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
    "sql_history_duration": m104,
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
    "sql_history_rows": m105,
    "sql_history_search_hint": MessageLookupByLibrary.simpleMessage("Search statements and connections"),
    "sql_history_succeeded": MessageLookupByLibrary.simpleMessage("Succeeded"),
    "sql_history_title": MessageLookupByLibrary.simpleMessage("History"),
    "sql_history_too_long": MessageLookupByLibrary.simpleMessage("Too long to keep"),
    "studio_error_copy_statement": MessageLookupByLibrary.simpleMessage("Copy statement"),
    "studio_error_fix_statement": MessageLookupByLibrary.simpleMessage(
      "An administrator can run this statement to fix it:",
    ),
    "studio_error_retry_in": m106,
    "studio_error_semantics": m107,
    "studio_error_statement_copied": MessageLookupByLibrary.simpleMessage("Statement copied"),
    "studio_governance_cannot_serve": MessageLookupByLibrary.simpleMessage(
      "Studio cannot serve connections right now. An administrator needs to check its governance setup.",
    ),
    "studio_governance_detail": m108,
    "studio_governance_temporarily_unavailable": MessageLookupByLibrary.simpleMessage(
      "Connection access is temporarily unavailable. The list updates by itself once it is back.",
    ),
    "studio_unreachable_host": m109,
    "studio_unreachable_message": MessageLookupByLibrary.simpleMessage(
      "LibreDB Studio does not answer. Check your internet connection, then try again.",
    ),
    "studio_unreachable_title": MessageLookupByLibrary.simpleMessage("Can\'t reach Studio"),
    "success": MessageLookupByLibrary.simpleMessage("Success"),
    "tab_browse": MessageLookupByLibrary.simpleMessage("Browse"),
    "tab_sql": MessageLookupByLibrary.simpleMessage("SQL"),
    "table_rows_listed": m110,
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "theme_dialog_subtitle": MessageLookupByLibrary.simpleMessage("Select your preferred theme style"),
    "theme_dialog_title": MessageLookupByLibrary.simpleMessage("Choose Theme"),
    "theme_palette_applied": m111,
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
    "write_confirm_name_label": m112,
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
    "write_confirm_reason_may_write_at": m113,
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
