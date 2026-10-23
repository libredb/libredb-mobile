// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false) ? locale.languageCode : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Admin`
  String get admin {
    return Intl.message('Admin', name: 'admin', desc: '', args: []);
  }

  /// `Role`
  String get role {
    return Intl.message('Role', name: 'role', desc: '', args: []);
  }

  /// `Login`
  String get login {
    return Intl.message('Login', name: 'login', desc: '', args: []);
  }

  /// `Active`
  String get active {
    return Intl.message('Active', name: 'active', desc: '', args: []);
  }

  /// `Authorities`
  String get authorities {
    return Intl.message('Authorities', name: 'authorities', desc: '', args: []);
  }

  /// `Name`
  String get name {
    return Intl.message('Name', name: 'name', desc: '', args: []);
  }

  /// `Success`
  String get success {
    return Intl.message('Success', name: 'success', desc: '', args: []);
  }

  /// `Failed`
  String get failed {
    return Intl.message('Failed', name: 'failed', desc: '', args: []);
  }

  /// `Required Field`
  String get required_field {
    return Intl.message('Required Field', name: 'required_field', desc: '', args: []);
  }

  /// `List`
  String get list {
    return Intl.message('List', name: 'list', desc: '', args: []);
  }

  /// `Turkish`
  String get turkish {
    return Intl.message('Turkish', name: 'turkish', desc: '', args: []);
  }

  /// `English`
  String get english {
    return Intl.message('English', name: 'english', desc: '', args: []);
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Back`
  String get back {
    return Intl.message('Back', name: 'back', desc: '', args: []);
  }

  /// `Are you sure you want to delete?`
  String get delete_confirmation {
    return Intl.message('Are you sure you want to delete?', name: 'delete_confirmation', desc: '', args: []);
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Account`
  String get account {
    return Intl.message('Account', name: 'account', desc: '', args: []);
  }

  /// `Select Language`
  String get language_select {
    return Intl.message('Select Language', name: 'language_select', desc: '', args: []);
  }

  /// `Logout`
  String get logout {
    return Intl.message('Logout', name: 'logout', desc: '', args: []);
  }

  /// `Are you sure you want to logout?`
  String get logout_sure {
    return Intl.message('Are you sure you want to logout?', name: 'logout_sure', desc: '', args: []);
  }

  /// `Yes`
  String get yes {
    return Intl.message('Yes', name: 'yes', desc: '', args: []);
  }

  /// `No`
  String get no {
    return Intl.message('No', name: 'no', desc: '', args: []);
  }

  /// `Warning`
  String get warning {
    return Intl.message('Warning', name: 'warning', desc: '', args: []);
  }

  /// `You have unsaved changes. Are you sure you want to leave?`
  String get unsaved_changes {
    return Intl.message(
      'You have unsaved changes. Are you sure you want to leave?',
      name: 'unsaved_changes',
      desc: '',
      args: [],
    );
  }

  /// `No Data`
  String get no_data {
    return Intl.message('No Data', name: 'no_data', desc: '', args: []);
  }

  /// `Loading...`
  String get loading {
    return Intl.message('Loading...', name: 'loading', desc: '', args: []);
  }

  /// `Theme`
  String get theme {
    return Intl.message('Theme', name: 'theme', desc: '', args: []);
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Refresh`
  String get refresh {
    return Intl.message('Refresh', name: 'refresh', desc: '', args: []);
  }

  /// `Join the Community`
  String get community_title {
    return Intl.message('Join the Community', name: 'community_title', desc: '', args: []);
  }

  /// `LibreDB's source code is public. Your contributions make it better!`
  String get community_subtitle {
    return Intl.message(
      'LibreDB\'s source code is public. Your contributions make it better!',
      name: 'community_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `Star & Fork`
  String get community_star {
    return Intl.message('Star & Fork', name: 'community_star', desc: '', args: []);
  }

  /// `Open an Issue`
  String get community_issue {
    return Intl.message('Open an Issue', name: 'community_issue', desc: '', args: []);
  }

  /// `Contribute`
  String get community_contribute {
    return Intl.message('Contribute', name: 'community_contribute', desc: '', args: []);
  }

  /// `Translate`
  String get community_translate {
    return Intl.message('Translate', name: 'community_translate', desc: '', args: []);
  }

  /// `Sponsor`
  String get community_sponsor {
    return Intl.message('Sponsor', name: 'community_sponsor', desc: '', args: []);
  }

  /// `Documentation`
  String get community_docs {
    return Intl.message('Documentation', name: 'community_docs', desc: '', args: []);
  }

  /// `Help & Resources`
  String get help_resources {
    return Intl.message('Help & Resources', name: 'help_resources', desc: '', args: []);
  }

  /// `Read the documentation and guides on GitHub`
  String get help_resources_subtitle {
    return Intl.message(
      'Read the documentation and guides on GitHub',
      name: 'help_resources_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `Documentation`
  String get documentation {
    return Intl.message('Documentation', name: 'documentation', desc: '', args: []);
  }

  /// `Invalid access token`
  String get error_auth_invalid_access_token {
    return Intl.message('Invalid access token', name: 'error_auth_invalid_access_token', desc: '', args: []);
  }

  /// `Could not save the session`
  String get error_auth_session_persist_failed {
    return Intl.message('Could not save the session', name: 'error_auth_session_persist_failed', desc: '', args: []);
  }

  /// `Admin user cannot be deleted`
  String get error_user_cannot_delete_admin {
    return Intl.message('Admin user cannot be deleted', name: 'error_user_cannot_delete_admin', desc: '', args: []);
  }

  /// `No authorities found`
  String get error_user_no_authorities {
    return Intl.message('No authorities found', name: 'error_user_no_authorities', desc: '', args: []);
  }

  /// `Could not change the language`
  String get error_settings_change_language_failed {
    return Intl.message(
      'Could not change the language',
      name: 'error_settings_change_language_failed',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong`
  String get error_generic {
    return Intl.message('Something went wrong', name: 'error_generic', desc: '', args: []);
  }

  /// `The connection could not be verified as secure, so it was blocked. Try again later or on another network.`
  String get error_network_cert_invalid {
    return Intl.message(
      'The connection could not be verified as secure, so it was blocked. Try again later or on another network.',
      name: 'error_network_cert_invalid',
      desc: '',
      args: [],
    );
  }

  /// `No internet connection. Check your network and try again.`
  String get error_network_offline {
    return Intl.message(
      'No internet connection. Check your network and try again.',
      name: 'error_network_offline',
      desc: '',
      args: [],
    );
  }

  /// `You were signed out due to inactivity.`
  String get idle_timeout_signed_out {
    return Intl.message('You were signed out due to inactivity.', name: 'idle_timeout_signed_out', desc: '', args: []);
  }

  /// `Could not open {url}`
  String error_link_open_failed(String url) {
    return Intl.message('Could not open $url', name: 'error_link_open_failed', desc: '', args: [url]);
  }

  /// `Update Required`
  String get force_update_title {
    return Intl.message('Update Required', name: 'force_update_title', desc: '', args: []);
  }

  /// `A new version is available. Please update to continue using the app.`
  String get force_update_message {
    return Intl.message(
      'A new version is available. Please update to continue using the app.',
      name: 'force_update_message',
      desc: '',
      args: [],
    );
  }

  /// `Current: {currentVersion}  •  Required: {minimumVersion}`
  String force_update_versions(String currentVersion, String minimumVersion) {
    return Intl.message(
      'Current: $currentVersion  •  Required: $minimumVersion',
      name: 'force_update_versions',
      desc: '',
      args: [currentVersion, minimumVersion],
    );
  }

  /// `Update Now`
  String get force_update_button {
    return Intl.message('Update Now', name: 'force_update_button', desc: '', args: []);
  }

  /// `Open your app store to install the latest version.`
  String get force_update_no_store_link {
    return Intl.message(
      'Open your app store to install the latest version.',
      name: 'force_update_no_store_link',
      desc: '',
      args: [],
    );
  }

  /// `The update link is not valid. Open your app store to install the latest version.`
  String get force_update_store_link_invalid {
    return Intl.message(
      'The update link is not valid. Open your app store to install the latest version.',
      name: 'force_update_store_link_invalid',
      desc: '',
      args: [],
    );
  }

  /// `Under Maintenance`
  String get maintenance_title {
    return Intl.message('Under Maintenance', name: 'maintenance_title', desc: '', args: []);
  }

  /// `We are performing scheduled maintenance. Please check back soon.`
  String get maintenance_message {
    return Intl.message(
      'We are performing scheduled maintenance. Please check back soon.',
      name: 'maintenance_message',
      desc: '',
      args: [],
    );
  }

  /// `Estimated end: {time}`
  String maintenance_estimated_end(String time) {
    return Intl.message('Estimated end: $time', name: 'maintenance_estimated_end', desc: '', args: [time]);
  }

  /// `Try Again`
  String get maintenance_retry {
    return Intl.message('Try Again', name: 'maintenance_retry', desc: '', args: []);
  }

  /// `You were signed out, but some stored data could not be removed from this device.`
  String get logout_stored_data_left {
    return Intl.message(
      'You were signed out, but some stored data could not be removed from this device.',
      name: 'logout_stored_data_left',
      desc: '',
      args: [],
    );
  }

  /// `Home`
  String get home {
    return Intl.message('Home', name: 'home', desc: '', args: []);
  }

  /// `Users`
  String get users {
    return Intl.message('Users', name: 'users', desc: '', args: []);
  }

  /// `New`
  String get new_item {
    return Intl.message('New', name: 'new_item', desc: '', args: []);
  }

  /// `Edit`
  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '', args: []);
  }

  /// `No internet connection`
  String get connectivity_offline {
    return Intl.message('No internet connection', name: 'connectivity_offline', desc: '', args: []);
  }

  /// `Offline: no internet connection. What is on screen was loaded earlier.`
  String get connectivity_offline_semantics {
    return Intl.message(
      'Offline: no internet connection. What is on screen was loaded earlier.',
      name: 'connectivity_offline_semantics',
      desc: '',
      args: [],
    );
  }

  /// `Offline: showing what was loaded at {time}`
  String offline_stale_data(String time) {
    return Intl.message(
      'Offline: showing what was loaded at $time',
      name: 'offline_stale_data',
      desc: '',
      args: [time],
    );
  }

  /// `Needs an internet connection`
  String get offline_action_unavailable {
    return Intl.message('Needs an internet connection', name: 'offline_action_unavailable', desc: '', args: []);
  }

  /// `Page Not Found`
  String get not_found_title {
    return Intl.message('Page Not Found', name: 'not_found_title', desc: '', args: []);
  }

  /// `The page you requested could not be found.`
  String get not_found_message {
    return Intl.message('The page you requested could not be found.', name: 'not_found_message', desc: '', args: []);
  }

  /// `Your databases,\nin your pocket.`
  String get login_brand_headline {
    return Intl.message('Your databases,\nin your pocket.', name: 'login_brand_headline', desc: '', args: []);
  }

  /// `Reach the databases LibreDB Studio grants you, from your phone.`
  String get login_brand_description {
    return Intl.message(
      'Reach the databases LibreDB Studio grants you, from your phone.',
      name: 'login_brand_description',
      desc: '',
      args: [],
    );
  }

  /// `Organization sign-in`
  String get login_feature_auth_title {
    return Intl.message('Organization sign-in', name: 'login_feature_auth_title', desc: '', args: []);
  }

  /// `Sign in with the account your organization manages in Keycloak.`
  String get login_feature_auth_description {
    return Intl.message(
      'Sign in with the account your organization manages in Keycloak.',
      name: 'login_feature_auth_description',
      desc: '',
      args: [],
    );
  }

  /// `No passwords on the phone`
  String get login_feature_credentials_title {
    return Intl.message('No passwords on the phone', name: 'login_feature_credentials_title', desc: '', args: []);
  }

  /// `Studio holds every database credential, and the app never stores one.`
  String get login_feature_credentials_description {
    return Intl.message(
      'Studio holds every database credential, and the app never stores one.',
      name: 'login_feature_credentials_description',
      desc: '',
      args: [],
    );
  }

  /// `Browse and query`
  String get login_feature_query_title {
    return Intl.message('Browse and query', name: 'login_feature_query_title', desc: '', args: []);
  }

  /// `Look through schemas and run queries on the connections you are given.`
  String get login_feature_query_description {
    return Intl.message(
      'Look through schemas and run queries on the connections you are given.',
      name: 'login_feature_query_description',
      desc: '',
      args: [],
    );
  }

  /// `Welcome back`
  String get login_welcome_title {
    return Intl.message('Welcome back', name: 'login_welcome_title', desc: '', args: []);
  }

  /// `Switch to light mode`
  String get login_switch_to_light_mode {
    return Intl.message('Switch to light mode', name: 'login_switch_to_light_mode', desc: '', args: []);
  }

  /// `Switch to dark mode`
  String get login_switch_to_dark_mode {
    return Intl.message('Switch to dark mode', name: 'login_switch_to_dark_mode', desc: '', args: []);
  }

  /// `Source Available`
  String get community_source_available {
    return Intl.message('Source Available', name: 'community_source_available', desc: '', args: []);
  }

  /// `Manage your account preferences`
  String get settings_subtitle {
    return Intl.message('Manage your account preferences', name: 'settings_subtitle', desc: '', args: []);
  }

  /// `Appearance`
  String get settings_appearance {
    return Intl.message('Appearance', name: 'settings_appearance', desc: '', args: []);
  }

  /// `Choose your preferred theme style`
  String get settings_theme_subtitle {
    return Intl.message('Choose your preferred theme style', name: 'settings_theme_subtitle', desc: '', args: []);
  }

  /// `Retry`
  String get retry {
    return Intl.message('Retry', name: 'retry', desc: '', args: []);
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Inactive`
  String get inactive {
    return Intl.message('Inactive', name: 'inactive', desc: '', args: []);
  }

  /// `Submit`
  String get submit {
    return Intl.message('Submit', name: 'submit', desc: '', args: []);
  }

  /// `Apply`
  String get apply {
    return Intl.message('Apply', name: 'apply', desc: '', args: []);
  }

  /// `Previous`
  String get previous {
    return Intl.message('Previous', name: 'previous', desc: '', args: []);
  }

  /// `Next`
  String get next {
    return Intl.message('Next', name: 'next', desc: '', args: []);
  }

  /// `{count, plural, =1{1 row listed.} other{{count} rows listed.}}`
  String table_rows_listed(int count) {
    return Intl.plural(
      count,
      one: '1 row listed.',
      other: '$count rows listed.',
      name: 'table_rows_listed',
      desc: '',
      args: [count],
    );
  }

  /// `Choose Theme`
  String get theme_dialog_title {
    return Intl.message('Choose Theme', name: 'theme_dialog_title', desc: '', args: []);
  }

  /// `Select your preferred theme style`
  String get theme_dialog_subtitle {
    return Intl.message('Select your preferred theme style', name: 'theme_dialog_subtitle', desc: '', args: []);
  }

  /// `Classic`
  String get theme_palette_classic {
    return Intl.message('Classic', name: 'theme_palette_classic', desc: '', args: []);
  }

  /// `Neutral zinc, clean and minimal`
  String get theme_palette_classic_description {
    return Intl.message(
      'Neutral zinc, clean and minimal',
      name: 'theme_palette_classic_description',
      desc: '',
      args: [],
    );
  }

  /// `Nature`
  String get theme_palette_nature {
    return Intl.message('Nature', name: 'theme_palette_nature', desc: '', args: []);
  }

  /// `Sage green, calm and organic`
  String get theme_palette_nature_description {
    return Intl.message('Sage green, calm and organic', name: 'theme_palette_nature_description', desc: '', args: []);
  }

  /// `Sunset`
  String get theme_palette_sunset {
    return Intl.message('Sunset', name: 'theme_palette_sunset', desc: '', args: []);
  }

  /// `Warm stone, rich and inviting`
  String get theme_palette_sunset_description {
    return Intl.message('Warm stone, rich and inviting', name: 'theme_palette_sunset_description', desc: '', args: []);
  }

  /// `LibreDB`
  String get app_title {
    return Intl.message('LibreDB', name: 'app_title', desc: '', args: []);
  }

  /// `Single sign-on is not configured correctly in this app. Contact your administrator.`
  String get error_auth_oidc_config {
    return Intl.message(
      'Single sign-on is not configured correctly in this app. Contact your administrator.',
      name: 'error_auth_oidc_config',
      desc: '',
      args: [],
    );
  }

  /// `The identity provider could not be reached. Try again later, or contact your administrator if this continues.`
  String get error_auth_oidc_discovery {
    return Intl.message(
      'The identity provider could not be reached. Try again later, or contact your administrator if this continues.',
      name: 'error_auth_oidc_discovery',
      desc: '',
      args: [],
    );
  }

  /// `Sign-in failed. Please try again.`
  String get error_auth_oidc_failed {
    return Intl.message('Sign-in failed. Please try again.', name: 'error_auth_oidc_failed', desc: '', args: []);
  }

  /// `You are signed out of this app, but your session at the identity provider may still be active.`
  String get error_auth_oidc_logout_incomplete {
    return Intl.message(
      'You are signed out of this app, but your session at the identity provider may still be active.',
      name: 'error_auth_oidc_logout_incomplete',
      desc: '',
      args: [],
    );
  }

  /// `Sign in with SSO`
  String get login_sso_button {
    return Intl.message('Sign in with SSO', name: 'login_sso_button', desc: '', args: []);
  }

  /// `Sign in with your organization account.`
  String get login_sso_subtitle {
    return Intl.message('Sign in with your organization account.', name: 'login_sso_subtitle', desc: '', args: []);
  }

  /// `Connections`
  String get connections {
    return Intl.message('Connections', name: 'connections', desc: '', args: []);
  }

  /// `No connections are available to you`
  String get connection_list_empty {
    return Intl.message('No connections are available to you', name: 'connection_list_empty', desc: '', args: []);
  }

  /// `No databases have been granted to you yet. Ask an administrator for access.`
  String get connection_list_empty_governed {
    return Intl.message(
      'No databases have been granted to you yet. Ask an administrator for access.',
      name: 'connection_list_empty_governed',
      desc: '',
      args: [],
    );
  }

  /// `Could not load the connections`
  String get connection_list_load_failed {
    return Intl.message('Could not load the connections', name: 'connection_list_load_failed', desc: '', args: []);
  }

  /// `Connections are unavailable`
  String get connection_list_unavailable {
    return Intl.message('Connections are unavailable', name: 'connection_list_unavailable', desc: '', args: []);
  }

  /// `Statements you run are recorded in full in this server's query log.`
  String get connection_statement_capture_full {
    return Intl.message(
      'Statements you run are recorded in full in this server\'s query log.',
      name: 'connection_statement_capture_full',
      desc: '',
      args: [],
    );
  }

  /// `Engine`
  String get connection_type {
    return Intl.message('Engine', name: 'connection_type', desc: '', args: []);
  }

  /// `Environment`
  String get connection_environment {
    return Intl.message('Environment', name: 'connection_environment', desc: '', args: []);
  }

  /// `Host`
  String get connection_host {
    return Intl.message('Host', name: 'connection_host', desc: '', args: []);
  }

  /// `Database`
  String get connection_database {
    return Intl.message('Database', name: 'connection_database', desc: '', args: []);
  }

  /// `Group`
  String get connection_group {
    return Intl.message('Group', name: 'connection_group', desc: '', args: []);
  }

  /// `Other`
  String get connection_group_other {
    return Intl.message('Other', name: 'connection_group_other', desc: '', args: []);
  }

  /// `Other`
  String get connection_environment_other {
    return Intl.message('Other', name: 'connection_environment_other', desc: '', args: []);
  }

  /// `Environment: {label}`
  String connection_environment_badge(String label) {
    return Intl.message('Environment: $label', name: 'connection_environment_badge', desc: '', args: [label]);
  }

  /// `Filter by environment`
  String get connection_environment_filter {
    return Intl.message('Filter by environment', name: 'connection_environment_filter', desc: '', args: []);
  }

  /// `Read only`
  String get connection_read_only {
    return Intl.message('Read only', name: 'connection_read_only', desc: '', args: []);
  }

  /// `Search connections`
  String get connection_search_hint {
    return Intl.message('Search connections', name: 'connection_search_hint', desc: '', args: []);
  }

  /// `Clear search`
  String get connection_search_clear {
    return Intl.message('Clear search', name: 'connection_search_clear', desc: '', args: []);
  }

  /// `No connections match`
  String get connection_search_no_match {
    return Intl.message('No connections match', name: 'connection_search_no_match', desc: '', args: []);
  }

  /// `Favorites`
  String get connection_favorites {
    return Intl.message('Favorites', name: 'connection_favorites', desc: '', args: []);
  }

  /// `Recent`
  String get connection_recent {
    return Intl.message('Recent', name: 'connection_recent', desc: '', args: []);
  }

  /// `Add to favorites`
  String get connection_star {
    return Intl.message('Add to favorites', name: 'connection_star', desc: '', args: []);
  }

  /// `Remove from favorites`
  String get connection_unstar {
    return Intl.message('Remove from favorites', name: 'connection_unstar', desc: '', args: []);
  }

  /// `Status`
  String get connection_status {
    return Intl.message('Status', name: 'connection_status', desc: '', args: []);
  }

  /// `Status: {status}`
  String connection_status_semantics(String status) {
    return Intl.message('Status: $status', name: 'connection_status_semantics', desc: '', args: [status]);
  }

  /// `Check`
  String get connection_check {
    return Intl.message('Check', name: 'connection_check', desc: '', args: []);
  }

  /// `Check anyway`
  String get connection_check_anyway {
    return Intl.message('Check anyway', name: 'connection_check_anyway', desc: '', args: []);
  }

  /// `Not checked yet`
  String get connection_check_idle {
    return Intl.message('Not checked yet', name: 'connection_check_idle', desc: '', args: []);
  }

  /// `Checking`
  String get connection_check_checking {
    return Intl.message('Checking', name: 'connection_check_checking', desc: '', args: []);
  }

  /// `Reachable, {latency} ms`
  String connection_check_online(int latency) {
    return Intl.message('Reachable, $latency ms', name: 'connection_check_online', desc: '', args: [latency]);
  }

  /// `Reachable`
  String get connection_check_online_no_latency {
    return Intl.message('Reachable', name: 'connection_check_online_no_latency', desc: '', args: []);
  }

  /// `Reachable, without health data`
  String get connection_check_degraded {
    return Intl.message('Reachable, without health data', name: 'connection_check_degraded', desc: '', args: []);
  }

  /// `Not checked: checking would start billed compute`
  String get connection_check_not_checked {
    return Intl.message(
      'Not checked: checking would start billed compute',
      name: 'connection_check_not_checked',
      desc: '',
      args: [],
    );
  }

  /// `Check failed`
  String get connection_check_failed {
    return Intl.message('Check failed', name: 'connection_check_failed', desc: '', args: []);
  }

  /// `The database refused the connection's credentials. Ask your administrator to check them.`
  String get error_studio_database_auth {
    return Intl.message(
      'The database refused the connection\'s credentials. Ask your administrator to check them.',
      name: 'error_studio_database_auth',
      desc: '',
      args: [],
    );
  }

  /// `This connection is not available to you.`
  String get error_studio_connection_not_available {
    return Intl.message(
      'This connection is not available to you.',
      name: 'error_studio_connection_not_available',
      desc: '',
      args: [],
    );
  }

  /// `The database did not allow this. You may lack a privilege on this object.`
  String get error_studio_permission_denied {
    return Intl.message(
      'The database did not allow this. You may lack a privilege on this object.',
      name: 'error_studio_permission_denied',
      desc: '',
      args: [],
    );
  }

  /// `Studio allows only the connections your administrator set up.`
  String get error_studio_custom_connections_disabled {
    return Intl.message(
      'Studio allows only the connections your administrator set up.',
      name: 'error_studio_custom_connections_disabled',
      desc: '',
      args: [],
    );
  }

  /// `The statement failed.`
  String get error_studio_query_error {
    return Intl.message('The statement failed.', name: 'error_studio_query_error', desc: '', args: []);
  }

  /// `The statement was cancelled.`
  String get error_studio_query_cancelled {
    return Intl.message('The statement was cancelled.', name: 'error_studio_query_cancelled', desc: '', args: []);
  }

  /// `The connection is not configured correctly. Contact your administrator.`
  String get error_studio_config_error {
    return Intl.message(
      'The connection is not configured correctly. Contact your administrator.',
      name: 'error_studio_config_error',
      desc: '',
      args: [],
    );
  }

  /// `The database did not answer in time.`
  String get error_studio_timeout {
    return Intl.message('The database did not answer in time.', name: 'error_studio_timeout', desc: '', args: []);
  }

  /// `The database could not be reached. Try again in a moment.`
  String get error_studio_database_unreachable {
    return Intl.message(
      'The database could not be reached. Try again in a moment.',
      name: 'error_studio_database_unreachable',
      desc: '',
      args: [],
    );
  }

  /// `Studio cannot check your access right now. Try again in a moment.`
  String get error_studio_governance_unavailable {
    return Intl.message(
      'Studio cannot check your access right now. Try again in a moment.',
      name: 'error_studio_governance_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `Studio cannot reach the identity provider right now. Try again in a moment.`
  String get error_studio_identity_provider_unavailable {
    return Intl.message(
      'Studio cannot reach the identity provider right now. Try again in a moment.',
      name: 'error_studio_identity_provider_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `Studio did not accept this sign-in. Try again, or ask an administrator for access.`
  String get error_studio_account_refused {
    return Intl.message(
      'Studio did not accept this sign-in. Try again, or ask an administrator for access.',
      name: 'error_studio_account_refused',
      desc: '',
      args: [],
    );
  }

  /// `This account has no role in Studio. Ask an administrator to give it one.`
  String get error_studio_account_has_no_role {
    return Intl.message(
      'This account has no role in Studio. Ask an administrator to give it one.',
      name: 'error_studio_account_has_no_role',
      desc: '',
      args: [],
    );
  }

  /// `Studio cannot tell who this account is. Ask an administrator to check the account's email and username.`
  String get error_studio_account_has_no_identity {
    return Intl.message(
      'Studio cannot tell who this account is. Ask an administrator to check the account\'s email and username.',
      name: 'error_studio_account_has_no_identity',
      desc: '',
      args: [],
    );
  }

  /// `Too many requests in a short time. Wait a moment and try again.`
  String get error_studio_rate_limited {
    return Intl.message(
      'Too many requests in a short time. Wait a moment and try again.',
      name: 'error_studio_rate_limited',
      desc: '',
      args: [],
    );
  }

  /// `Another session holds an open transaction on this connection.`
  String get error_studio_transaction_not_owned {
    return Intl.message(
      'Another session holds an open transaction on this connection.',
      name: 'error_studio_transaction_not_owned',
      desc: '',
      args: [],
    );
  }

  /// `Your access to this connection changed, so the transaction was rolled back.`
  String get error_studio_transaction_credential_changed {
    return Intl.message(
      'Your access to this connection changed, so the transaction was rolled back.',
      name: 'error_studio_transaction_credential_changed',
      desc: '',
      args: [],
    );
  }

  /// `Studio sent an answer this app cannot read. The app or Studio may need an update.`
  String get error_studio_unreadable_answer {
    return Intl.message(
      'Studio sent an answer this app cannot read. The app or Studio may need an update.',
      name: 'error_studio_unreadable_answer',
      desc: '',
      args: [],
    );
  }

  /// `Licenses`
  String get settings_licenses {
    return Intl.message('Licenses', name: 'settings_licenses', desc: '', args: []);
  }

  /// `The licenses of LibreDB Mobile and the code it includes`
  String get settings_licenses_subtitle {
    return Intl.message(
      'The licenses of LibreDB Mobile and the code it includes',
      name: 'settings_licenses_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `You can try again in {seconds} s.`
  String studio_error_retry_in(int seconds) {
    return Intl.message('You can try again in $seconds s.', name: 'studio_error_retry_in', desc: '', args: [seconds]);
  }

  /// `An administrator can run this statement to fix it:`
  String get studio_error_fix_statement {
    return Intl.message(
      'An administrator can run this statement to fix it:',
      name: 'studio_error_fix_statement',
      desc: '',
      args: [],
    );
  }

  /// `Copy statement`
  String get studio_error_copy_statement {
    return Intl.message('Copy statement', name: 'studio_error_copy_statement', desc: '', args: []);
  }

  /// `Statement copied`
  String get studio_error_statement_copied {
    return Intl.message('Statement copied', name: 'studio_error_statement_copied', desc: '', args: []);
  }

  /// `Error: {message}`
  String studio_error_semantics(String message) {
    return Intl.message('Error: $message', name: 'studio_error_semantics', desc: '', args: [message]);
  }

  /// `Can't reach Studio`
  String get studio_unreachable_title {
    return Intl.message('Can\'t reach Studio', name: 'studio_unreachable_title', desc: '', args: []);
  }

  /// `LibreDB Studio does not answer. Check your internet connection, then try again.`
  String get studio_unreachable_message {
    return Intl.message(
      'LibreDB Studio does not answer. Check your internet connection, then try again.',
      name: 'studio_unreachable_message',
      desc: '',
      args: [],
    );
  }

  /// `Studio address: {host}`
  String studio_unreachable_host(String host) {
    return Intl.message('Studio address: $host', name: 'studio_unreachable_host', desc: '', args: [host]);
  }

  /// `Connection access is temporarily unavailable. The list updates by itself once it is back.`
  String get studio_governance_temporarily_unavailable {
    return Intl.message(
      'Connection access is temporarily unavailable. The list updates by itself once it is back.',
      name: 'studio_governance_temporarily_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `Studio cannot serve connections right now. An administrator needs to check its governance setup.`
  String get studio_governance_cannot_serve {
    return Intl.message(
      'Studio cannot serve connections right now. An administrator needs to check its governance setup.',
      name: 'studio_governance_cannot_serve',
      desc: '',
      args: [],
    );
  }

  /// `Details: {detail}`
  String studio_governance_detail(String detail) {
    return Intl.message('Details: $detail', name: 'studio_governance_detail', desc: '', args: [detail]);
  }

  /// `Profile`
  String get profile {
    return Intl.message('Profile', name: 'profile', desc: '', args: []);
  }

  /// `Unknown user`
  String get profile_unknown_user {
    return Intl.message('Unknown user', name: 'profile_unknown_user', desc: '', args: []);
  }

  /// `Administrator`
  String get profile_role_admin {
    return Intl.message('Administrator', name: 'profile_role_admin', desc: '', args: []);
  }

  /// `User`
  String get profile_role_user {
    return Intl.message('User', name: 'profile_role_user', desc: '', args: []);
  }

  /// `Governed by LibreDB Platform`
  String get profile_governed_by_platform {
    return Intl.message('Governed by LibreDB Platform', name: 'profile_governed_by_platform', desc: '', args: []);
  }

  /// `Browse`
  String get tab_browse {
    return Intl.message('Browse', name: 'tab_browse', desc: '', args: []);
  }

  /// `SQL`
  String get tab_sql {
    return Intl.message('SQL', name: 'tab_sql', desc: '', args: []);
  }

  /// `Pick a connection first`
  String get pick_connection_first {
    return Intl.message('Pick a connection first', name: 'pick_connection_first', desc: '', args: []);
  }

  /// `Open a connection from the Connections tab to use this tab.`
  String get pick_connection_first_description {
    return Intl.message(
      'Open a connection from the Connections tab to use this tab.',
      name: 'pick_connection_first_description',
      desc: '',
      args: [],
    );
  }

  /// `Objects`
  String get browse_objects {
    return Intl.message(
      'Objects',
      name: 'browse_objects',
      desc: 'The heading of the kind screen of a connection whose engine has no container level, such as SQLite.',
      args: [],
    );
  }

  /// `Studio lists nothing at this level.`
  String get browse_level_empty {
    return Intl.message('Studio lists nothing at this level.', name: 'browse_level_empty', desc: '', args: []);
  }

  /// `Studio counts no objects here.`
  String get browse_kinds_empty {
    return Intl.message('Studio counts no objects here.', name: 'browse_kinds_empty', desc: '', args: []);
  }

  /// `Source`
  String get browse_source {
    return Intl.message('Source', name: 'browse_source', desc: '', args: []);
  }

  /// `Regenerated by Studio, not the stored text`
  String get browse_source_regenerated {
    return Intl.message(
      'Regenerated by Studio, not the stored text',
      name: 'browse_source_regenerated',
      desc: '',
      args: [],
    );
  }

  /// `Partial`
  String get browse_source_partial {
    return Intl.message('Partial', name: 'browse_source_partial', desc: '', args: []);
  }

  /// `Truncated: {reason}`
  String browse_source_truncated(String reason) {
    return Intl.message('Truncated: $reason', name: 'browse_source_truncated', desc: '', args: [reason]);
  }

  /// `This definition could not be read`
  String get browse_source_unavailable {
    return Intl.message('This definition could not be read', name: 'browse_source_unavailable', desc: '', args: []);
  }

  /// `Copy all`
  String get browse_source_copy {
    return Intl.message('Copy all', name: 'browse_source_copy', desc: '', args: []);
  }

  /// `Copied`
  String get browse_source_copied {
    return Intl.message('Copied', name: 'browse_source_copied', desc: '', args: []);
  }

  /// `Could not copy ({code})`
  String browse_source_copy_failed(String code) {
    return Intl.message('Could not copy ($code)', name: 'browse_source_copy_failed', desc: '', args: [code]);
  }

  /// `Share`
  String get browse_source_share {
    return Intl.message('Share', name: 'browse_source_share', desc: '', args: []);
  }

  /// `Could not share ({code})`
  String browse_source_share_failed(String code) {
    return Intl.message('Could not share ($code)', name: 'browse_source_share_failed', desc: '', args: [code]);
  }

  /// `{count, plural, =1{1 object} other{{formatted} objects}}`
  String browse_objects_count(int count, String formatted) {
    return Intl.plural(
      count,
      one: '1 object',
      other: '$formatted objects',
      name: 'browse_objects_count',
      desc: 'How many objects of a kind a container holds.',
      args: [count, formatted],
    );
  }

  /// `{matched} of {total} match`
  String browse_objects_match(int matched, int total) {
    final NumberFormat matchedNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String matchedString = matchedNumberFormat.format(matched);

    final NumberFormat totalNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String totalString = totalNumberFormat.format(total);

    return Intl.message(
      '$matchedString of $totalString match',
      name: 'browse_objects_match',
      desc: 'While filtering a list: how many of its objects the filter matches.',
      args: [matchedString, totalString],
    );
  }

  /// `Studio lists no objects of this kind here.`
  String get browse_objects_empty {
    return Intl.message('Studio lists no objects of this kind here.', name: 'browse_objects_empty', desc: '', args: []);
  }

  /// `{count, plural, =1{1 row} other{{formatted} rows}}`
  String browse_object_rows(int count, String formatted) {
    return Intl.plural(
      count,
      one: '1 row',
      other: '$formatted rows',
      name: 'browse_object_rows',
      desc: 'The row count an engine reports for a table, an estimate on most engines.',
      args: [count, formatted],
    );
  }

  /// `On {parent}`
  String browse_object_attached_to(String parent) {
    return Intl.message(
      'On $parent',
      name: 'browse_object_attached_to',
      desc: 'Secondary text of an attached object, such as a trigger: the object it hangs under.',
      args: [parent],
    );
  }

  /// `Invalid`
  String get browse_object_status_invalid {
    return Intl.message(
      'Invalid',
      name: 'browse_object_status_invalid',
      desc: 'Badge of an object the engine reports as INVALID, such as an Oracle package that does not compile.',
      args: [],
    );
  }

  /// `Disabled`
  String get browse_object_status_disabled {
    return Intl.message(
      'Disabled',
      name: 'browse_object_status_disabled',
      desc: 'Badge of an object the engine reports as DISABLED, such as a trigger.',
      args: [],
    );
  }

  /// `Copy name`
  String get browse_object_copy_name {
    return Intl.message('Copy name', name: 'browse_object_copy_name', desc: '', args: []);
  }

  /// `View source`
  String get browse_object_view_source {
    return Intl.message('View source', name: 'browse_object_view_source', desc: '', args: []);
  }

  /// `Name copied`
  String get browse_object_name_copied {
    return Intl.message('Name copied', name: 'browse_object_name_copied', desc: '', args: []);
  }

  /// `Search objects`
  String get browse_search_action {
    return Intl.message('Search objects', name: 'browse_search_action', desc: '', args: []);
  }

  /// `Search`
  String get browse_search_title {
    return Intl.message('Search', name: 'browse_search_title', desc: '', args: []);
  }

  /// `Search by name`
  String get browse_search_hint {
    return Intl.message('Search by name', name: 'browse_search_hint', desc: '', args: []);
  }

  /// `Clear search`
  String get browse_search_clear {
    return Intl.message('Clear search', name: 'browse_search_clear', desc: '', args: []);
  }

  /// `Type at least {count} characters to search.`
  String browse_search_min_length(int count) {
    return Intl.message(
      'Type at least $count characters to search.',
      name: 'browse_search_min_length',
      desc: '',
      args: [count],
    );
  }

  /// `No object's name holds "{term}".`
  String browse_search_no_results(String term) {
    return Intl.message('No object\'s name holds "$term".', name: 'browse_search_no_results', desc: '', args: [term]);
  }

  /// `Search is not available on this connection; browse instead`
  String get browse_search_not_available {
    return Intl.message(
      'Search is not available on this connection; browse instead',
      name: 'browse_search_not_available',
      desc: '',
      args: [],
    );
  }

  /// `Filter`
  String get local_filter_hint {
    return Intl.message('Filter', name: 'local_filter_hint', desc: '', args: []);
  }

  /// `Clear filter`
  String get local_filter_clear {
    return Intl.message('Clear filter', name: 'local_filter_clear', desc: '', args: []);
  }

  /// `Nothing matches the filter.`
  String get local_filter_no_match {
    return Intl.message('Nothing matches the filter.', name: 'local_filter_no_match', desc: '', args: []);
  }

  /// `Details`
  String get browse_details {
    return Intl.message(
      'Details',
      name: 'browse_details',
      desc: 'Opens the columns, indexes and foreign keys of an object from its source page.',
      args: [],
    );
  }

  /// `Columns`
  String get browse_detail_columns {
    return Intl.message('Columns', name: 'browse_detail_columns', desc: '', args: []);
  }

  /// `Indexes`
  String get browse_detail_indexes {
    return Intl.message('Indexes', name: 'browse_detail_indexes', desc: '', args: []);
  }

  /// `Foreign keys`
  String get browse_detail_foreign_keys {
    return Intl.message('Foreign keys', name: 'browse_detail_foreign_keys', desc: '', args: []);
  }

  /// `Columns inferred from sampled documents`
  String get browse_detail_sampled {
    return Intl.message(
      'Columns inferred from sampled documents',
      name: 'browse_detail_sampled',
      desc: 'A caption above the columns when Studio inferred any of them from sampled documents.',
      args: [],
    );
  }

  /// `{type} (sampled)`
  String browse_detail_sampled_type(String type) {
    return Intl.message('$type (sampled)', name: 'browse_detail_sampled_type', desc: '', args: [type]);
  }

  /// `Primary key`
  String get browse_detail_primary_key {
    return Intl.message('Primary key', name: 'browse_detail_primary_key', desc: '', args: []);
  }

  /// `Nullable`
  String get browse_detail_nullable {
    return Intl.message('Nullable', name: 'browse_detail_nullable', desc: '', args: []);
  }

  /// `Default: {value}`
  String browse_detail_default(String value) {
    return Intl.message('Default: $value', name: 'browse_detail_default', desc: '', args: [value]);
  }

  /// `Unique`
  String get browse_detail_unique {
    return Intl.message('Unique', name: 'browse_detail_unique', desc: '', args: []);
  }

  /// `Studio lists no columns.`
  String get browse_detail_no_columns {
    return Intl.message('Studio lists no columns.', name: 'browse_detail_no_columns', desc: '', args: []);
  }

  /// `Studio lists no indexes.`
  String get browse_detail_no_indexes {
    return Intl.message('Studio lists no indexes.', name: 'browse_detail_no_indexes', desc: '', args: []);
  }

  /// `Studio lists no foreign keys.`
  String get browse_detail_no_foreign_keys {
    return Intl.message('Studio lists no foreign keys.', name: 'browse_detail_no_foreign_keys', desc: '', args: []);
  }

  /// `Could not check which tables these keys open ({code})`
  String browse_detail_links_unchecked(String code) {
    return Intl.message(
      'Could not check which tables these keys open ($code)',
      name: 'browse_detail_links_unchecked',
      desc: 'Over foreign keys whose tables could not be looked up, with the error code of the refused list.',
      args: [code],
    );
  }

  /// `Exclusion constraints`
  String get browse_detail_exclusion_constraints {
    return Intl.message('Exclusion constraints', name: 'browse_detail_exclusion_constraints', desc: '', args: []);
  }

  /// `References {table}.{column}`
  String browse_detail_references(String table, String column) {
    return Intl.message(
      'References $table.$column',
      name: 'browse_detail_references',
      desc: 'The table and column a foreign key points to.',
      args: [table, column],
    );
  }

  /// `Your account has no access to Studio`
  String get account_refusal_title {
    return Intl.message('Your account has no access to Studio', name: 'account_refusal_title', desc: '', args: []);
  }

  /// `{name} is no longer available`
  String connection_vanished(String name) {
    return Intl.message('$name is no longer available', name: 'connection_vanished', desc: '', args: [name]);
  }

  /// `Switch connection`
  String get connection_switcher_title {
    return Intl.message('Switch connection', name: 'connection_switcher_title', desc: '', args: []);
  }

  /// `Active connection`
  String get connection_active {
    return Intl.message('Active connection', name: 'connection_active', desc: '', args: []);
  }

  /// `Browse keys`
  String get keys_browse {
    return Intl.message(
      'Browse keys',
      name: 'keys_browse',
      desc: 'The row of a kind screen that opens the key browser.',
      args: [],
    );
  }

  /// `Keys`
  String get keys_title {
    return Intl.message('Keys', name: 'keys_title', desc: '', args: []);
  }

  /// `Pattern`
  String get keys_pattern_glob {
    return Intl.message(
      'Pattern',
      name: 'keys_pattern_glob',
      desc: 'The label of the key browser\'s pattern field when the engine takes a glob, such as user:*.',
      args: [],
    );
  }

  /// `Starts with`
  String get keys_pattern_prefix {
    return Intl.message(
      'Starts with',
      name: 'keys_pattern_prefix',
      desc: 'The label of the key browser\'s pattern field when the engine takes a literal prefix.',
      args: [],
    );
  }

  /// `{count, plural, =1{Scanned 1 key} other{Scanned {count} keys}}`
  String keys_scanned(int count) {
    return Intl.plural(
      count,
      one: 'Scanned 1 key',
      other: 'Scanned $count keys',
      name: 'keys_scanned',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, =1{Scanned 1 key; more remain} other{Scanned {count} keys; more remain}}`
  String keys_scanned_more(int count) {
    return Intl.plural(
      count,
      one: 'Scanned 1 key; more remain',
      other: 'Scanned $count keys; more remain',
      name: 'keys_scanned_more',
      desc: '',
      args: [count],
    );
  }

  /// `Scanned {count} of the {total} keys this database holds`
  String keys_scanned_of_database(int count, int total) {
    return Intl.message(
      'Scanned $count of the $total keys this database holds',
      name: 'keys_scanned_of_database',
      desc: '',
      args: [count, total],
    );
  }

  /// `Scanned {count} of the {total} keys this database holds; more remain`
  String keys_scanned_of_database_more(int count, int total) {
    return Intl.message(
      'Scanned $count of the $total keys this database holds; more remain',
      name: 'keys_scanned_of_database_more',
      desc: '',
      args: [count, total],
    );
  }

  /// `Scanned {count} of the {total} keys this walk covers`
  String keys_scanned_of_walk(int count, int total) {
    return Intl.message(
      'Scanned $count of the $total keys this walk covers',
      name: 'keys_scanned_of_walk',
      desc: '',
      args: [count, total],
    );
  }

  /// `Scanned {count} of the {total} keys this walk covers; more remain`
  String keys_scanned_of_walk_more(int count, int total) {
    return Intl.message(
      'Scanned $count of the $total keys this walk covers; more remain',
      name: 'keys_scanned_of_walk_more',
      desc: '',
      args: [count, total],
    );
  }

  /// `{count, plural, =1{Listed 1 entry} other{Listed {count} entries}}`
  String keys_listed(int count) {
    return Intl.plural(
      count,
      one: 'Listed 1 entry',
      other: 'Listed $count entries',
      name: 'keys_listed',
      desc: '',
      args: [count],
    );
  }

  /// `{count, plural, =1{Listed 1 entry; more remain} other{Listed {count} entries; more remain}}`
  String keys_listed_more(int count) {
    return Intl.plural(
      count,
      one: 'Listed 1 entry; more remain',
      other: 'Listed $count entries; more remain',
      name: 'keys_listed_more',
      desc: '',
      args: [count],
    );
  }

  /// `Clustered server: SCAN and DBSIZE answer for one node at a time, so these counts are this node's.`
  String get keys_clustered {
    return Intl.message(
      'Clustered server: SCAN and DBSIZE answer for one node at a time, so these counts are this node\'s.',
      name: 'keys_clustered',
      desc: '',
      args: [],
    );
  }

  /// `{count, plural, =1{1 key left out of this walk: {reason}} other{{count} keys left out of this walk: {reason}}}`
  String keys_skipped(int count, String reason) {
    return Intl.plural(
      count,
      one: '1 key left out of this walk: $reason',
      other: '$count keys left out of this walk: $reason',
      name: 'keys_skipped',
      desc: '',
      args: [count, reason],
    );
  }

  /// `This list is incomplete, and the engine can show why: {reason}`
  String keys_read_incomplete(String reason) {
    return Intl.message(
      'This list is incomplete, and the engine can show why: $reason',
      name: 'keys_read_incomplete',
      desc: '',
      args: [reason],
    );
  }

  /// `This list is what the read saw. Whether it is everything cannot be established on this engine: {reason}`
  String keys_read_unknown(String reason) {
    return Intl.message(
      'This list is what the read saw. Whether it is everything cannot be established on this engine: $reason',
      name: 'keys_read_unknown',
      desc: '',
      args: [reason],
    );
  }

  /// `Load more`
  String get keys_load_more {
    return Intl.message('Load more', name: 'keys_load_more', desc: '', args: []);
  }

  /// `Load all`
  String get keys_load_all {
    return Intl.message('Load all', name: 'keys_load_all', desc: '', args: []);
  }

  /// `Stop`
  String get keys_stop {
    return Intl.message('Stop', name: 'keys_stop', desc: '', args: []);
  }

  /// `Stopping after this page`
  String get keys_stopping {
    return Intl.message('Stopping after this page', name: 'keys_stopping', desc: '', args: []);
  }

  /// `This screen holds at most 10,000 keys: narrow the pattern to see the others.`
  String get keys_cap {
    return Intl.message(
      'This screen holds at most 10,000 keys: narrow the pattern to see the others.',
      name: 'keys_cap',
      desc: '',
      args: [],
    );
  }

  /// `Studio found no keys here.`
  String get keys_empty {
    return Intl.message('Studio found no keys here.', name: 'keys_empty', desc: '', args: []);
  }

  /// `Studio declares no key browser for this connection.`
  String get keys_unavailable {
    return Intl.message(
      'Studio declares no key browser for this connection.',
      name: 'keys_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `Null value`
  String get cell_null_semantics {
    return Intl.message('Null value', name: 'cell_null_semantics', desc: '', args: []);
  }

  /// `{count, plural, =1{1 row, {time} ms} other{{rows} rows, {time} ms}}`
  String result_stats(int count, String rows, String time) {
    return Intl.plural(
      count,
      one: '1 row, $time ms',
      other: '$rows rows, $time ms',
      name: 'result_stats',
      desc: 'The stats strip of a result: the rows shown and how long the statement ran.',
      args: [count, rows, time],
    );
  }

  /// `{count, plural, =1{1 warning} other{{count} warnings}}`
  String result_warnings(int count) {
    return Intl.plural(
      count,
      one: '1 warning',
      other: '$count warnings',
      name: 'result_warnings',
      desc: 'The chip that opens and shuts the warnings the engine reported.',
      args: [count],
    );
  }

  /// `{severity}: {message}`
  String result_warning_line(String severity, String message) {
    return Intl.message(
      '$severity: $message',
      name: 'result_warning_line',
      desc: 'One warning with its severity, both as Studio wrote them.',
      args: [severity, message],
    );
  }

  /// `Warning`
  String get result_warning_fallback {
    return Intl.message(
      'Warning',
      name: 'result_warning_fallback',
      desc: 'A warning the engine sent without a message.',
      args: [],
    );
  }

  /// `Code {code}`
  String result_warning_code(String code) {
    return Intl.message(
      'Code $code',
      name: 'result_warning_code',
      desc: 'The engine\'s code of a warning.',
      args: [code],
    );
  }

  /// `The engine reported:`
  String get result_engine_reported {
    return Intl.message(
      'The engine reported:',
      name: 'result_engine_reported',
      desc: 'Above the warnings of a result with no rows.',
      args: [],
    );
  }

  /// `limited`
  String get result_limited {
    return Intl.message(
      'limited',
      name: 'result_limited',
      desc: 'Studio\'s badge on a result it bounded, in lower case as Studio writes it.',
      args: [],
    );
  }

  /// `Studio bounded this result. Anything beyond the bound is not in it.`
  String get result_limited_notice {
    return Intl.message(
      'Studio bounded this result. Anything beyond the bound is not in it.',
      name: 'result_limited_notice',
      desc: 'What the limited badge means.',
      args: [],
    );
  }

  /// `This statement left a transaction open, and Studio rolled it back, so its changes were discarded.`
  String get result_rolled_back {
    return Intl.message(
      'This statement left a transaction open, and Studio rolled it back, so its changes were discarded.',
      name: 'result_rolled_back',
      desc: 'Studio rolled back a transaction the statement left open.',
      args: [],
    );
  }

  /// `{count, plural, =1{1 row affected} other{{rows} rows affected}}`
  String result_affected_rows(int count, String rows) {
    return Intl.plural(
      count,
      one: '1 row affected',
      other: '$rows rows affected',
      name: 'result_affected_rows',
      desc: 'A write statement\'s answer: the rows it changed.',
      args: [count, rows],
    );
  }

  /// `No row is shown: the result was cut before its first row`
  String get result_empty_bounded {
    return Intl.message(
      'No row is shown: the result was cut before its first row',
      name: 'result_empty_bounded',
      desc: 'An empty result Studio bounded.',
      args: [],
    );
  }

  /// `Query returned no data`
  String get result_empty {
    return Intl.message('Query returned no data', name: 'result_empty', desc: 'A result with no rows.', args: []);
  }

  /// `Row {index}`
  String result_row_title(int index) {
    return Intl.message(
      'Row $index',
      name: 'result_row_title',
      desc: 'The title of a result card whose title field is NULL.',
      args: [index],
    );
  }

  /// `#{id}`
  String result_card_id(String id) {
    return Intl.message('#$id', name: 'result_card_id', desc: 'The id field under a result card\'s title.', args: [id]);
  }

  /// `{count, plural, =1{+1 more field} other{+{count} more fields}}`
  String result_more_fields(int count) {
    return Intl.plural(
      count,
      one: '+1 more field',
      other: '+$count more fields',
      name: 'result_more_fields',
      desc: 'Under a result card: the fields it does not show.',
      args: [count],
    );
  }

  /// `Masked value`
  String get result_masked_semantics {
    return Intl.message(
      'Masked value',
      name: 'result_masked_semantics',
      desc: 'What a screen reader says for the lock on a masked field.',
      args: [],
    );
  }

  /// `Row {index} of {count}`
  String result_row_position(int index, int count) {
    return Intl.message(
      'Row $index of $count',
      name: 'result_row_position',
      desc: 'The row detail sheet\'s title: the row\'s place among the rows loaded.',
      args: [index, count],
    );
  }

  /// `Copy value`
  String get result_copy_value {
    return Intl.message('Copy value', name: 'result_copy_value', desc: 'Copies one field of a result row.', args: []);
  }

  /// `Copy row as JSON`
  String get result_copy_row {
    return Intl.message(
      'Copy row as JSON',
      name: 'result_copy_row',
      desc: 'Copies a whole result row as JSON.',
      args: [],
    );
  }

  /// `Copied`
  String get result_copied {
    return Intl.message('Copied', name: 'result_copied', desc: 'A result value or row was copied.', args: []);
  }

  /// `Could not copy ({code})`
  String result_copy_failed(String code) {
    return Intl.message(
      'Could not copy ($code)',
      name: 'result_copy_failed',
      desc: 'A copy of a result value failed; code is the error\'s code.',
      args: [code],
    );
  }

  /// `View rows`
  String get browse_view_rows {
    return Intl.message(
      'View rows',
      name: 'browse_view_rows',
      desc: 'Opens the first rows of a table, a view or a collection.',
      args: [],
    );
  }

  /// `Count rows`
  String get browse_count_rows {
    return Intl.message(
      'Count rows',
      name: 'browse_count_rows',
      desc: 'Runs a count of the rows of a table, a view or a collection.',
      args: [],
    );
  }

  /// `Preview is not available for this engine yet`
  String get browse_preview_unavailable {
    return Intl.message(
      'Preview is not available for this engine yet',
      name: 'browse_preview_unavailable',
      desc: 'Why View rows is disabled for an object whose engine\'s preview the app does not write yet.',
      args: [],
    );
  }

  /// `Could not count the rows ({code})`
  String browse_count_failed(String code) {
    return Intl.message(
      'Could not count the rows ($code)',
      name: 'browse_count_failed',
      desc: 'In a heading, when the row count was refused or could not be read, with its error code.',
      args: [code],
    );
  }

  /// `The database says`
  String get browse_rows_database_says {
    return Intl.message(
      'The database says',
      name: 'browse_rows_database_says',
      desc: 'Over the database\'s own words for a failed preview.',
      args: [],
    );
  }

  /// `Cards`
  String get result_view_cards {
    return Intl.message(
      'Cards',
      name: 'result_view_cards',
      desc: 'The result view mode that shows a card per row.',
      args: [],
    );
  }

  /// `Table`
  String get result_view_table {
    return Intl.message(
      'Table',
      name: 'result_view_table',
      desc: 'The result view mode that shows the rows as a table.',
      args: [],
    );
  }

  /// `{count, plural, =1{Load 1 more} other{Load {rows} more}}`
  String result_load_more(int count, String rows) {
    return Intl.plural(
      count,
      one: 'Load 1 more',
      other: 'Load $rows more',
      name: 'result_load_more',
      desc: 'Fetches the next page of a result, of the page size already on screen.',
      args: [count, rows],
    );
  }

  /// `{count, plural, =1{Loading 1 more…} other{Loading {rows} more…}}`
  String result_loading_more(int count, String rows) {
    return Intl.plural(
      count,
      one: 'Loading 1 more…',
      other: 'Loading $rows more…',
      name: 'result_loading_more',
      desc: 'The next page of a result is in flight.',
      args: [count, rows],
    );
  }

  /// `Without an ORDER BY the engine may return rows that repeat or are skipped between pages.`
  String get result_order_notice {
    return Intl.message(
      'Without an ORDER BY the engine may return rows that repeat or are skipped between pages.',
      name: 'result_order_notice',
      desc: 'Studio\'s notice for a paged result whose statement has no outer ORDER BY.',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[Locale.fromSubtags(languageCode: 'en'), Locale.fromSubtags(languageCode: 'tr')];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
