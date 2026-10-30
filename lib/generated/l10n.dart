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

  /// `Are you sure you want to delete?`
  String get delete_confirmation {
    return Intl.message('Are you sure you want to delete?', name: 'delete_confirmation', desc: '', args: []);
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
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

  /// `Introduction`
  String get settings_introduction {
    return Intl.message('Introduction', name: 'settings_introduction', desc: '', args: []);
  }

  /// `Watch the six introduction screens again`
  String get settings_introduction_subtitle {
    return Intl.message(
      'Watch the six introduction screens again',
      name: 'settings_introduction_subtitle',
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

  /// `Skip`
  String get onboarding_skip {
    return Intl.message('Skip', name: 'onboarding_skip', desc: '', args: []);
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

  /// `Day and night`
  String get brightness {
    return Intl.message(
      'Day and night',
      name: 'brightness',
      desc: 'The Appearance settings tile that picks whether the app is light, dark or follows the phone.',
      args: [],
    );
  }

  /// `Day and night`
  String get brightness_dialog_title {
    return Intl.message('Day and night', name: 'brightness_dialog_title', desc: '', args: []);
  }

  /// `Choose light, dark, or whatever the phone is set to`
  String get brightness_dialog_subtitle {
    return Intl.message(
      'Choose light, dark, or whatever the phone is set to',
      name: 'brightness_dialog_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `Follow the phone`
  String get brightness_system {
    return Intl.message(
      'Follow the phone',
      name: 'brightness_system',
      desc: 'ThemeMode.system: the app is light or dark as the phone\'s own setting says.',
      args: [],
    );
  }

  /// `Light or dark, as the phone's own setting says`
  String get brightness_system_description {
    return Intl.message(
      'Light or dark, as the phone\'s own setting says',
      name: 'brightness_system_description',
      desc: '',
      args: [],
    );
  }

  /// `Light`
  String get brightness_light {
    return Intl.message('Light', name: 'brightness_light', desc: '', args: []);
  }

  /// `Always light, whatever the phone is set to`
  String get brightness_light_description {
    return Intl.message(
      'Always light, whatever the phone is set to',
      name: 'brightness_light_description',
      desc: '',
      args: [],
    );
  }

  /// `Dark`
  String get brightness_dark {
    return Intl.message('Dark', name: 'brightness_dark', desc: '', args: []);
  }

  /// `Always dark, whatever the phone is set to`
  String get brightness_dark_description {
    return Intl.message(
      'Always dark, whatever the phone is set to',
      name: 'brightness_dark_description',
      desc: '',
      args: [],
    );
  }

  /// `{mode} applied`
  String brightness_applied(String mode) {
    return Intl.message(
      '$mode applied',
      name: 'brightness_applied',
      desc: 'Announced to a screen reader when a mode is applied from the day and night dialog.',
      args: [mode],
    );
  }

  /// `{palette} theme applied`
  String theme_palette_applied(String palette) {
    return Intl.message(
      '$palette theme applied',
      name: 'theme_palette_applied',
      desc: 'Announced to a screen reader when a palette is applied from the theme dialog.',
      args: [palette],
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

  /// `Cool neutral, clean and minimal`
  String get theme_palette_classic_description {
    return Intl.message(
      'Cool neutral, clean and minimal',
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

  /// `This build has no sign-in settings. Ask whoever gave you the app for a complete build.`
  String get error_auth_oidc_config {
    return Intl.message(
      'This build has no sign-in settings. Ask whoever gave you the app for a complete build.',
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

  /// `Files shared on this phone earlier could not be removed, so you are not signed in. Try again.`
  String get error_auth_share_files_not_removed {
    return Intl.message(
      'Files shared on this phone earlier could not be removed, so you are not signed in. Try again.',
      name: 'error_auth_share_files_not_removed',
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

  /// `Sign in to Studio`
  String get login_studio_button {
    return Intl.message('Sign in to Studio', name: 'login_studio_button', desc: '', args: []);
  }

  /// `Browse and query the databases Studio grants you.`
  String get login_studio_helper {
    return Intl.message(
      'Browse and query the databases Studio grants you.',
      name: 'login_studio_helper',
      desc: '',
      args: [],
    );
  }

  /// `Sign in to Platform`
  String get login_platform_button {
    return Intl.message('Sign in to Platform', name: 'login_platform_button', desc: '', args: []);
  }

  /// `For Platform admins. Your first Platform sign-in takes one admin seat of the license.`
  String get login_platform_helper {
    return Intl.message(
      'For Platform admins. Your first Platform sign-in takes one admin seat of the license.',
      name: 'login_platform_helper',
      desc: '',
      args: [],
    );
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

  /// `Can't reach Platform`
  String get platform_status_unreachable_title {
    return Intl.message('Can\'t reach Platform', name: 'platform_status_unreachable_title', desc: '', args: []);
  }

  /// `LibreDB Platform does not answer. Check your internet connection, then try again.`
  String get platform_status_unreachable_message {
    return Intl.message(
      'LibreDB Platform does not answer. Check your internet connection, then try again.',
      name: 'platform_status_unreachable_message',
      desc: '',
      args: [],
    );
  }

  /// `Platform address: {host}`
  String platform_status_unreachable_host(String host) {
    return Intl.message('Platform address: $host', name: 'platform_status_unreachable_host', desc: '', args: [host]);
  }

  /// `Studio does not answer.`
  String get login_unreachable_studio {
    return Intl.message('Studio does not answer.', name: 'login_unreachable_studio', desc: '', args: []);
  }

  /// `Platform does not answer.`
  String get login_unreachable_platform {
    return Intl.message('Platform does not answer.', name: 'login_unreachable_platform', desc: '', args: []);
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

  /// `Studio`
  String get profile_mode_studio {
    return Intl.message('Studio', name: 'profile_mode_studio', desc: '', args: []);
  }

  /// `Platform admin`
  String get profile_mode_platform {
    return Intl.message('Platform admin', name: 'profile_mode_platform', desc: '', args: []);
  }

  /// `Switch to Platform`
  String get profile_switch_to_platform {
    return Intl.message('Switch to Platform', name: 'profile_switch_to_platform', desc: '', args: []);
  }

  /// `Switch to Studio`
  String get profile_switch_to_studio {
    return Intl.message('Switch to Studio', name: 'profile_switch_to_studio', desc: '', args: []);
  }

  /// `Switch to Platform?`
  String get profile_switch_platform_title {
    return Intl.message('Switch to Platform?', name: 'profile_switch_platform_title', desc: '', args: []);
  }

  /// `Platform mode is for Platform admins. The first time this account opens Platform, it takes one admin seat of the license.`
  String get profile_switch_platform_message {
    return Intl.message(
      'Platform mode is for Platform admins. The first time this account opens Platform, it takes one admin seat of the license.',
      name: 'profile_switch_platform_message',
      desc: '',
      args: [],
    );
  }

  /// `Switch`
  String get profile_switch_confirm {
    return Intl.message('Switch', name: 'profile_switch_confirm', desc: '', args: []);
  }

  /// `This account is not a Platform admin, so it stays in Studio.`
  String get profile_switch_admin_role_required {
    return Intl.message(
      'This account is not a Platform admin, so it stays in Studio.',
      name: 'profile_switch_admin_role_required',
      desc: '',
      args: [],
    );
  }

  /// `Platform did not accept this account, so it stays in Studio. Ask an administrator to check that this app is set up for Platform.`
  String get profile_switch_platform_refused {
    return Intl.message(
      'Platform did not accept this account, so it stays in Studio. Ask an administrator to check that this app is set up for Platform.',
      name: 'profile_switch_platform_refused',
      desc: '',
      args: [],
    );
  }

  /// `Studio did not accept this account, so it stays in Platform. Ask an administrator for access.`
  String get profile_switch_studio_refused {
    return Intl.message(
      'Studio did not accept this account, so it stays in Platform. Ask an administrator for access.',
      name: 'profile_switch_studio_refused',
      desc: '',
      args: [],
    );
  }

  /// `Studio does not answer, so this account stays in Platform. Try again in a moment.`
  String get profile_switch_studio_unreachable {
    return Intl.message(
      'Studio does not answer, so this account stays in Platform. Try again in a moment.',
      name: 'profile_switch_studio_unreachable',
      desc: '',
      args: [],
    );
  }

  /// `Platform does not answer, so this account stays in Studio. Try again in a moment.`
  String get profile_switch_platform_unreachable {
    return Intl.message(
      'Platform does not answer, so this account stays in Studio. Try again in a moment.',
      name: 'profile_switch_platform_unreachable',
      desc: '',
      args: [],
    );
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

  /// `Could not share: {reason}`
  String browse_source_share_failed_reason(String reason) {
    return Intl.message(
      'Could not share: $reason',
      name: 'browse_source_share_failed_reason',
      desc: 'A share of a source failed without an error code; reason is the localized generic error message.',
      args: [reason],
    );
  }

  /// `The shared file stays on this phone until you sign out: {reason}`
  String browse_source_share_file_left(String reason) {
    return Intl.message(
      'The shared file stays on this phone until you sign out: $reason',
      name: 'browse_source_share_file_left',
      desc: 'The file of a source shared as a file could not be removed once the share ended; the sign-out removes it. reason is the localized generic error message.',
      args: [reason],
    );
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

  /// `Could not check which tables these keys open: {reason}`
  String browse_detail_links_unchecked_reason(String reason) {
    return Intl.message(
      'Could not check which tables these keys open: $reason',
      name: 'browse_detail_links_unchecked_reason',
      desc: 'Over foreign keys whose tables could not be looked up, when the list failed without an error code; reason is the localized generic error message.',
      args: [reason],
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

  /// `LibreDB Platform refused your account`
  String get platform_account_refusal_title {
    return Intl.message(
      'LibreDB Platform refused your account',
      name: 'platform_account_refusal_title',
      desc: '',
      args: [],
    );
  }

  /// `{name} is no longer available`
  String connection_vanished(String name) {
    return Intl.message('$name is no longer available', name: 'connection_vanished', desc: '', args: [name]);
  }

  /// `Could not load the grants`
  String get platform_grants_load_failed {
    return Intl.message('Could not load the grants', name: 'platform_grants_load_failed', desc: '', args: []);
  }

  /// `Could not refresh the grants`
  String get platform_grants_refresh_failed {
    return Intl.message('Could not refresh the grants', name: 'platform_grants_refresh_failed', desc: '', args: []);
  }

  /// `No one has access yet`
  String get platform_grants_empty_title {
    return Intl.message('No one has access yet', name: 'platform_grants_empty_title', desc: '', args: []);
  }

  /// `No one holds a grant on this connection.`
  String get platform_grants_empty_description {
    return Intl.message(
      'No one holds a grant on this connection.',
      name: 'platform_grants_empty_description',
      desc: '',
      args: [],
    );
  }

  /// `This connection no longer exists`
  String get platform_grants_connection_gone_title {
    return Intl.message(
      'This connection no longer exists',
      name: 'platform_grants_connection_gone_title',
      desc: '',
      args: [],
    );
  }

  /// `It may have been deleted in the Platform web console.`
  String get platform_grants_connection_gone_description {
    return Intl.message(
      'It may have been deleted in the Platform web console.',
      name: 'platform_grants_connection_gone_description',
      desc: '',
      args: [],
    );
  }

  /// `Back to connections`
  String get platform_grants_back_to_connections {
    return Intl.message('Back to connections', name: 'platform_grants_back_to_connections', desc: '', args: []);
  }

  /// `Read`
  String get platform_grants_level_read {
    return Intl.message('Read', name: 'platform_grants_level_read', desc: '', args: []);
  }

  /// `Write`
  String get platform_grants_level_write {
    return Intl.message('Write', name: 'platform_grants_level_write', desc: '', args: []);
  }

  /// `read`
  String get platform_grants_level_read_in_sentence {
    return Intl.message('read', name: 'platform_grants_level_read_in_sentence', desc: '', args: []);
  }

  /// `write`
  String get platform_grants_level_write_in_sentence {
    return Intl.message('write', name: 'platform_grants_level_write_in_sentence', desc: '', args: []);
  }

  /// `No expiry`
  String get platform_grants_no_expiry {
    return Intl.message('No expiry', name: 'platform_grants_no_expiry', desc: '', args: []);
  }

  /// `Expires {date}`
  String platform_grants_expires(String date) {
    return Intl.message('Expires $date', name: 'platform_grants_expires', desc: '', args: [date]);
  }

  /// `Expired {date}`
  String platform_grants_expired(String date) {
    return Intl.message('Expired $date', name: 'platform_grants_expired', desc: '', args: [date]);
  }

  /// `Granted by {name}, {date}`
  String platform_grants_granted_by(String name, String date) {
    return Intl.message('Granted by $name, $date', name: 'platform_grants_granted_by', desc: '', args: [name, date]);
  }

  /// `Grant actions`
  String get platform_grants_actions {
    return Intl.message('Grant actions', name: 'platform_grants_actions', desc: '', args: []);
  }

  /// `Remove access`
  String get platform_grants_remove_access {
    return Intl.message('Remove access', name: 'platform_grants_remove_access', desc: '', args: []);
  }

  /// `{username} will lose {level} access to {connection}.`
  String platform_grants_remove_message(String username, String level, String connection) {
    return Intl.message(
      '$username will lose $level access to $connection.',
      name: 'platform_grants_remove_message',
      desc: '',
      args: [username, level, connection],
    );
  }

  /// `Remove`
  String get platform_grants_remove_confirm {
    return Intl.message('Remove', name: 'platform_grants_remove_confirm', desc: '', args: []);
  }

  /// `Access removed`
  String get platform_grants_removed {
    return Intl.message('Access removed', name: 'platform_grants_removed', desc: '', args: []);
  }

  /// `Already removed`
  String get platform_grants_already_removed {
    return Intl.message('Already removed', name: 'platform_grants_already_removed', desc: '', args: []);
  }

  /// `Add access`
  String get platform_grants_add {
    return Intl.message('Add access', name: 'platform_grants_add', desc: '', args: []);
  }

  /// `Change access`
  String get platform_grants_edit {
    return Intl.message('Change access', name: 'platform_grants_edit', desc: '', args: []);
  }

  /// `Choose a user`
  String get platform_grants_picker_title {
    return Intl.message('Choose a user', name: 'platform_grants_picker_title', desc: '', args: []);
  }

  /// `Search by username, name or e-mail`
  String get platform_grants_picker_search_hint {
    return Intl.message(
      'Search by username, name or e-mail',
      name: 'platform_grants_picker_search_hint',
      desc: '',
      args: [],
    );
  }

  /// `Clear search`
  String get platform_grants_picker_clear {
    return Intl.message('Clear search', name: 'platform_grants_picker_clear', desc: '', args: []);
  }

  /// `The search text is too long. Use at most 255 characters.`
  String get platform_grants_picker_query_too_long {
    return Intl.message(
      'The search text is too long. Use at most 255 characters.',
      name: 'platform_grants_picker_query_too_long',
      desc: '',
      args: [],
    );
  }

  /// `No user found`
  String get platform_grants_picker_empty_title {
    return Intl.message('No user found', name: 'platform_grants_picker_empty_title', desc: '', args: []);
  }

  /// `No Keycloak user matches this search.`
  String get platform_grants_picker_empty_description {
    return Intl.message(
      'No Keycloak user matches this search.',
      name: 'platform_grants_picker_empty_description',
      desc: '',
      args: [],
    );
  }

  /// `Could not search the directory`
  String get platform_grants_picker_load_failed {
    return Intl.message(
      'Could not search the directory',
      name: 'platform_grants_picker_load_failed',
      desc: '',
      args: [],
    );
  }

  /// `Load more`
  String get platform_grants_picker_load_more {
    return Intl.message('Load more', name: 'platform_grants_picker_load_more', desc: '', args: []);
  }

  /// `Could not load more users`
  String get platform_grants_picker_load_more_failed {
    return Intl.message(
      'Could not load more users',
      name: 'platform_grants_picker_load_more_failed',
      desc: '',
      args: [],
    );
  }

  /// `Studio admin`
  String get platform_grants_picker_role_admin {
    return Intl.message('Studio admin', name: 'platform_grants_picker_role_admin', desc: '', args: []);
  }

  /// `Studio user`
  String get platform_grants_picker_role_user {
    return Intl.message('Studio user', name: 'platform_grants_picker_role_user', desc: '', args: []);
  }

  /// `No Studio role, cannot sign in to Studio`
  String get platform_grants_picker_role_none {
    return Intl.message(
      'No Studio role, cannot sign in to Studio',
      name: 'platform_grants_picker_role_none',
      desc: '',
      args: [],
    );
  }

  /// `Disabled in Keycloak`
  String get platform_grants_picker_disabled {
    return Intl.message('Disabled in Keycloak', name: 'platform_grants_picker_disabled', desc: '', args: []);
  }

  /// `Takes a user seat`
  String get platform_grants_picker_takes_seat {
    return Intl.message('Takes a user seat', name: 'platform_grants_picker_takes_seat', desc: '', args: []);
  }

  /// `Takes a user seat when the connection is active again`
  String get platform_grants_picker_takes_seat_inactive {
    return Intl.message(
      'Takes a user seat when the connection is active again',
      name: 'platform_grants_picker_takes_seat_inactive',
      desc: '',
      args: [],
    );
  }

  /// `Give access to {connection}`
  String platform_grants_editor_title_new(String connection) {
    return Intl.message(
      'Give access to $connection',
      name: 'platform_grants_editor_title_new',
      desc: '',
      args: [connection],
    );
  }

  /// `Change access to {connection}`
  String platform_grants_editor_title_edit(String connection) {
    return Intl.message(
      'Change access to $connection',
      name: 'platform_grants_editor_title_edit',
      desc: '',
      args: [connection],
    );
  }

  /// `Choose another user`
  String get platform_grants_editor_change_user {
    return Intl.message('Choose another user', name: 'platform_grants_editor_change_user', desc: '', args: []);
  }

  /// `Access level`
  String get platform_grants_editor_level {
    return Intl.message('Access level', name: 'platform_grants_editor_level', desc: '', args: []);
  }

  /// `This connection has no write credential, so only read access can be granted.`
  String get platform_grants_editor_write_unavailable {
    return Intl.message(
      'This connection has no write credential, so only read access can be granted.',
      name: 'platform_grants_editor_write_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `Choose an access level.`
  String get platform_grants_editor_level_missing {
    return Intl.message('Choose an access level.', name: 'platform_grants_editor_level_missing', desc: '', args: []);
  }

  /// `Expiry`
  String get platform_grants_editor_expiry {
    return Intl.message('Expiry', name: 'platform_grants_editor_expiry', desc: '', args: []);
  }

  /// `Never expires`
  String get platform_grants_editor_expiry_never {
    return Intl.message('Never expires', name: 'platform_grants_editor_expiry_never', desc: '', args: []);
  }

  /// `Expires on {date}`
  String platform_grants_editor_expiry_on(String date) {
    return Intl.message('Expires on $date', name: 'platform_grants_editor_expiry_on', desc: '', args: [date]);
  }

  /// `Pick a date and time`
  String get platform_grants_editor_expiry_pick {
    return Intl.message('Pick a date and time', name: 'platform_grants_editor_expiry_pick', desc: '', args: []);
  }

  /// `In this device's time zone.`
  String get platform_grants_editor_expiry_local_time {
    return Intl.message(
      'In this device\'s time zone.',
      name: 'platform_grants_editor_expiry_local_time',
      desc: '',
      args: [],
    );
  }

  /// `Choose a time in the future, or no expiry.`
  String get platform_grants_editor_expiry_not_in_future {
    return Intl.message(
      'Choose a time in the future, or no expiry.',
      name: 'platform_grants_editor_expiry_not_in_future',
      desc: '',
      args: [],
    );
  }

  /// `This user has no Studio role and cannot sign in to Studio until a Keycloak admin gives them one.`
  String get platform_grants_editor_no_role_note {
    return Intl.message(
      'This user has no Studio role and cannot sign in to Studio until a Keycloak admin gives them one.',
      name: 'platform_grants_editor_no_role_note',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get platform_grants_editor_save {
    return Intl.message('Save', name: 'platform_grants_editor_save', desc: '', args: []);
  }

  /// `Access saved`
  String get platform_grants_editor_saved {
    return Intl.message('Access saved', name: 'platform_grants_editor_saved', desc: '', args: []);
  }

  /// `The license does not allow this grant`
  String get platform_grants_editor_license_title {
    return Intl.message(
      'The license does not allow this grant',
      name: 'platform_grants_editor_license_title',
      desc: '',
      args: [],
    );
  }

  /// `Platform could not check the user`
  String get platform_grants_editor_retry_title {
    return Intl.message(
      'Platform could not check the user',
      name: 'platform_grants_editor_retry_title',
      desc: '',
      args: [],
    );
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

  /// `{count, plural, =1{Scanned 1 key} other{Scanned {formatted} keys}}`
  String keys_scanned(int count, String formatted) {
    return Intl.plural(
      count,
      one: 'Scanned 1 key',
      other: 'Scanned $formatted keys',
      name: 'keys_scanned',
      desc: '',
      args: [count, formatted],
    );
  }

  /// `{count, plural, =1{Scanned 1 key; more remain} other{Scanned {formatted} keys; more remain}}`
  String keys_scanned_more(int count, String formatted) {
    return Intl.plural(
      count,
      one: 'Scanned 1 key; more remain',
      other: 'Scanned $formatted keys; more remain',
      name: 'keys_scanned_more',
      desc: '',
      args: [count, formatted],
    );
  }

  /// `Scanned {count} of the {total} keys this database holds`
  String keys_scanned_of_database(int count, int total) {
    final NumberFormat countNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String countString = countNumberFormat.format(count);

    final NumberFormat totalNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String totalString = totalNumberFormat.format(total);

    return Intl.message(
      'Scanned $countString of the $totalString keys this database holds',
      name: 'keys_scanned_of_database',
      desc: '',
      args: [countString, totalString],
    );
  }

  /// `Scanned {count} of the {total} keys this database holds; more remain`
  String keys_scanned_of_database_more(int count, int total) {
    final NumberFormat countNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String countString = countNumberFormat.format(count);

    final NumberFormat totalNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String totalString = totalNumberFormat.format(total);

    return Intl.message(
      'Scanned $countString of the $totalString keys this database holds; more remain',
      name: 'keys_scanned_of_database_more',
      desc: '',
      args: [countString, totalString],
    );
  }

  /// `Scanned {count} of the {total} keys this walk covers`
  String keys_scanned_of_walk(int count, int total) {
    final NumberFormat countNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String countString = countNumberFormat.format(count);

    final NumberFormat totalNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String totalString = totalNumberFormat.format(total);

    return Intl.message(
      'Scanned $countString of the $totalString keys this walk covers',
      name: 'keys_scanned_of_walk',
      desc: '',
      args: [countString, totalString],
    );
  }

  /// `Scanned {count} of the {total} keys this walk covers; more remain`
  String keys_scanned_of_walk_more(int count, int total) {
    final NumberFormat countNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String countString = countNumberFormat.format(count);

    final NumberFormat totalNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String totalString = totalNumberFormat.format(total);

    return Intl.message(
      'Scanned $countString of the $totalString keys this walk covers; more remain',
      name: 'keys_scanned_of_walk_more',
      desc: '',
      args: [countString, totalString],
    );
  }

  /// `{count, plural, =1{Found 1 matching key} other{Found {formatted} matching keys}}`
  String keys_found(int count, String formatted) {
    return Intl.plural(
      count,
      one: 'Found 1 matching key',
      other: 'Found $formatted matching keys',
      name: 'keys_found',
      desc: 'The key browser\'s progress under a pattern: the keys the walk returned, which match the pattern.',
      args: [count, formatted],
    );
  }

  /// `{count, plural, =1{Found 1 matching key; more remain} other{Found {formatted} matching keys; more remain}}`
  String keys_found_more(int count, String formatted) {
    return Intl.plural(
      count,
      one: 'Found 1 matching key; more remain',
      other: 'Found $formatted matching keys; more remain',
      name: 'keys_found_more',
      desc: '',
      args: [count, formatted],
    );
  }

  /// `{count, plural, =1{Found 1 matching key; the database holds {total}} other{Found {formatted} matching keys; the database holds {total}}}`
  String keys_found_of_database(int count, String formatted, String total) {
    return Intl.plural(
      count,
      one: 'Found 1 matching key; the database holds $total',
      other: 'Found $formatted matching keys; the database holds $total',
      name: 'keys_found_of_database',
      desc: 'The key browser\'s progress under a pattern, with the count of every key the database holds; {total} is formatted.',
      args: [count, formatted, total],
    );
  }

  /// `{count, plural, =1{Found 1 matching key; the database holds {total}; more remain} other{Found {formatted} matching keys; the database holds {total}; more remain}}`
  String keys_found_of_database_more(int count, String formatted, String total) {
    return Intl.plural(
      count,
      one: 'Found 1 matching key; the database holds $total; more remain',
      other: 'Found $formatted matching keys; the database holds $total; more remain',
      name: 'keys_found_of_database_more',
      desc: '',
      args: [count, formatted, total],
    );
  }

  /// `Found {count} of the {total} keys this walk covers`
  String keys_found_of_walk(int count, int total) {
    final NumberFormat countNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String countString = countNumberFormat.format(count);

    final NumberFormat totalNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String totalString = totalNumberFormat.format(total);

    return Intl.message(
      'Found $countString of the $totalString keys this walk covers',
      name: 'keys_found_of_walk',
      desc: '',
      args: [countString, totalString],
    );
  }

  /// `Found {count} of the {total} keys this walk covers; more remain`
  String keys_found_of_walk_more(int count, int total) {
    final NumberFormat countNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String countString = countNumberFormat.format(count);

    final NumberFormat totalNumberFormat = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    final String totalString = totalNumberFormat.format(total);

    return Intl.message(
      'Found $countString of the $totalString keys this walk covers; more remain',
      name: 'keys_found_of_walk_more',
      desc: '',
      args: [countString, totalString],
    );
  }

  /// `{count, plural, =1{Listed 1 entry} other{Listed {formatted} entries}}`
  String keys_listed(int count, String formatted) {
    return Intl.plural(
      count,
      one: 'Listed 1 entry',
      other: 'Listed $formatted entries',
      name: 'keys_listed',
      desc: '',
      args: [count, formatted],
    );
  }

  /// `{count, plural, =1{Listed 1 entry; more remain} other{Listed {formatted} entries; more remain}}`
  String keys_listed_more(int count, String formatted) {
    return Intl.plural(
      count,
      one: 'Listed 1 entry; more remain',
      other: 'Listed $formatted entries; more remain',
      name: 'keys_listed_more',
      desc: '',
      args: [count, formatted],
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

  /// `{count, plural, =1{1 key left out of this walk: {reason}} other{{formatted} keys left out of this walk: {reason}}}`
  String keys_skipped(int count, String formatted, String reason) {
    return Intl.plural(
      count,
      one: '1 key left out of this walk: $reason',
      other: '$formatted keys left out of this walk: $reason',
      name: 'keys_skipped',
      desc: '',
      args: [count, formatted, reason],
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

  /// `Warning {code}`
  String result_warning_fallback_code(String code) {
    return Intl.message(
      'Warning $code',
      name: 'result_warning_fallback_code',
      desc: 'A warning the engine sent without a message but with its code, as Studio\'s describeWarning words it.',
      args: [code],
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

  /// `Open in editor`
  String get browse_open_in_editor {
    return Intl.message(
      'Open in editor',
      name: 'browse_open_in_editor',
      desc: 'Opens the generated SELECT of a table, a view or a collection in the SQL editor, without running it.',
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

  /// `Could not count the rows: {reason}`
  String browse_count_failed_reason(String reason) {
    return Intl.message(
      'Could not count the rows: $reason',
      name: 'browse_count_failed_reason',
      desc: 'In a heading, when the row count failed without an error code; reason is the localized generic error message.',
      args: [reason],
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

  /// `Key`
  String get keys_value_overline {
    return Intl.message(
      'Key',
      name: 'keys_value_overline',
      desc: 'Over a key\'s name, at the head of its value page.',
      args: [],
    );
  }

  /// `This key no longer exists. Pull to read it again.`
  String get keys_value_vanished {
    return Intl.message(
      'This key no longer exists. Pull to read it again.',
      name: 'keys_value_vanished',
      desc: 'On a key\'s value page, when Redis answered that the key was deleted or expired after the key list was read.',
      args: [],
    );
  }

  /// `Studio says this key's type is {type}.`
  String keys_value_type(String type) {
    return Intl.message(
      'Studio says this key\'s type is $type.',
      name: 'keys_value_type',
      desc: 'On a key\'s value page when the key list named no type, with the type Redis answered.',
      args: [type],
    );
  }

  /// `Read value`
  String get keys_value_read {
    return Intl.message(
      'Read value',
      name: 'keys_value_read',
      desc: 'Runs the read of a key\'s value for the type Redis answered.',
      args: [],
    );
  }

  /// `The app has no read for this type.`
  String get keys_value_no_read {
    return Intl.message(
      'The app has no read for this type.',
      name: 'keys_value_no_read',
      desc: 'On a key\'s value page, under a type that none of the app\'s key reads covers.',
      args: [],
    );
  }

  /// `Reading a key's value is not available for this engine.`
  String get keys_value_unavailable {
    return Intl.message(
      'Reading a key\'s value is not available for this engine.',
      name: 'keys_value_unavailable',
      desc: 'On a key\'s value page opened for an engine that is not read with Redis commands.',
      args: [],
    );
  }

  /// `The statement text saved on this phone cannot be read. It may have come from a backup of another device, or the file was changed. Discard it to keep new text again.`
  String get error_editor_saved_text_unreadable {
    return Intl.message(
      'The statement text saved on this phone cannot be read. It may have come from a backup of another device, or the file was changed. Discard it to keep new text again.',
      name: 'error_editor_saved_text_unreadable',
      desc: 'A saved draft or statement history cannot be read; the screen offers Discard next to it.',
      args: [],
    );
  }

  /// `This phone could not save the statement text. Check its free storage and try again.`
  String get error_editor_saved_text_not_stored {
    return Intl.message(
      'This phone could not save the statement text. Check its free storage and try again.',
      name: 'error_editor_saved_text_not_stored',
      desc: 'The device refused to store or remove saved statement text.',
      args: [],
    );
  }

  /// `Loading more was interrupted when the app went to the background; Studio cancelled it.`
  String get error_editor_page_interrupted {
    return Intl.message(
      'Loading more was interrupted when the app went to the background; Studio cancelled it.',
      name: 'error_editor_page_interrupted',
      desc: 'Load more of a read was interrupted because the app went to the background, and Studio cancelled the run of that page.',
      args: [],
    );
  }

  /// `Loading more was interrupted in the background, and its outcome is unknown: each page runs the whole statement again, so check the data before running it again.`
  String get error_editor_page_outcome_unknown {
    return Intl.message(
      'Loading more was interrupted in the background, and its outcome is unknown: each page runs the whole statement again, so check the data before running it again.',
      name: 'error_editor_page_outcome_unknown',
      desc: 'Load more of a statement that may write was interrupted while the app was in the background, so whether the run of that page wrote is unknown.',
      args: [],
    );
  }

  /// `Reading the rows was interrupted when the app went to the background; Studio cancelled it.`
  String get error_browse_rows_interrupted {
    return Intl.message(
      'Reading the rows was interrupted when the app went to the background; Studio cancelled it.',
      name: 'error_browse_rows_interrupted',
      desc: 'The rows of an object on the Browse rows page were not read because the app went to the background, and Studio cancelled the run.',
      args: [],
    );
  }

  /// `Discard`
  String get editor_saved_text_discard {
    return Intl.message(
      'Discard',
      name: 'editor_saved_text_discard',
      desc: 'Deletes saved statement text that cannot be read, after a confirmation.',
      args: [],
    );
  }

  /// `Discard the saved text?`
  String get editor_saved_text_discard_title {
    return Intl.message(
      'Discard the saved text?',
      name: 'editor_saved_text_discard_title',
      desc: 'Title of the confirmation before saved statement text that cannot be read is deleted.',
      args: [],
    );
  }

  /// `The saved text that cannot be read is deleted from this phone. This cannot be undone.`
  String get editor_saved_text_discard_message {
    return Intl.message(
      'The saved text that cannot be read is deleted from this phone. This cannot be undone.',
      name: 'editor_saved_text_discard_message',
      desc: 'Body of the confirmation before saved statement text that cannot be read is deleted.',
      args: [],
    );
  }

  /// `Confirm before running`
  String get write_confirm_title {
    return Intl.message(
      'Confirm before running',
      name: 'write_confirm_title',
      desc: 'The title of the sheet that asks before a statement that may write runs.',
      args: [],
    );
  }

  /// `May change data: {word} on line {line}`
  String write_confirm_reason_may_write_at(String word, int line) {
    return Intl.message(
      'May change data: $word on line $line',
      name: 'write_confirm_reason_may_write_at',
      desc: 'A reason the statement asks: the word that may write and the line it is on.',
      args: [word, line],
    );
  }

  /// `May change data: the app cannot tell how the statement starts`
  String get write_confirm_reason_may_write {
    return Intl.message(
      'May change data: the app cannot tell how the statement starts',
      name: 'write_confirm_reason_may_write',
      desc: 'A reason the statement asks, when no first word could be read, such as after a comment that never closes.',
      args: [],
    );
  }

  /// `Runs more than one statement`
  String get write_confirm_reason_several {
    return Intl.message(
      'Runs more than one statement',
      name: 'write_confirm_reason_several',
      desc: 'A reason the statement asks: the text holds a separator followed by more text, or a GO or / line.',
      args: [],
    );
  }

  /// `The app cannot read what a command of this engine does`
  String get write_confirm_reason_not_sql {
    return Intl.message(
      'The app cannot read what a command of this engine does',
      name: 'write_confirm_reason_not_sql',
      desc: 'A reason the statement asks: the connection\'s engine does not use SQL, so every command asks.',
      args: [],
    );
  }

  /// `Your access to this connection is read only, so Studio will refuse a write here. An administrator can raise it.`
  String get write_confirm_read_grant {
    return Intl.message(
      'Your access to this connection is read only, so Studio will refuse a write here. An administrator can raise it.',
      name: 'write_confirm_read_grant',
      desc: 'On the confirmation sheet, when the user\'s grant on the connection is read only.',
      args: [],
    );
  }

  /// `This connection is set read only by its operator, so Studio or the database will refuse a write here.`
  String get write_confirm_read_only_connection {
    return Intl.message(
      'This connection is set read only by its operator, so Studio or the database will refuse a write here.',
      name: 'write_confirm_read_only_connection',
      desc: 'On the confirmation sheet, when the connection itself is marked read only in Studio\'s configuration.',
      args: [],
    );
  }

  /// `This is a production connection. Type its name to run the statement.`
  String get write_confirm_production_prompt {
    return Intl.message(
      'This is a production connection. Type its name to run the statement.',
      name: 'write_confirm_production_prompt',
      desc: 'On the confirmation sheet of a production connection, above the field for the connection\'s name.',
      args: [],
    );
  }

  /// `Type "{name}" to confirm`
  String write_confirm_name_label(String name) {
    return Intl.message(
      'Type "$name" to confirm',
      name: 'write_confirm_name_label',
      desc: 'The label of the field the user types the production connection\'s name in; the quotes show a leading or trailing space of the name.',
      args: [name],
    );
  }

  /// `This production connection has no name to type, so the statement cannot be confirmed here.`
  String get write_confirm_no_name {
    return Intl.message(
      'This production connection has no name to type, so the statement cannot be confirmed here.',
      name: 'write_confirm_no_name',
      desc: 'On the confirmation sheet of a production connection that has no name, in place of the name field.',
      args: [],
    );
  }

  /// `What will run`
  String get write_confirm_text_heading {
    return Intl.message(
      'What will run',
      name: 'write_confirm_text_heading',
      desc: 'Above the lines of the statement the sheet confirms.',
      args: [],
    );
  }

  /// `Run`
  String get write_confirm_run {
    return Intl.message('Run', name: 'write_confirm_run', desc: 'Runs the confirmed statement.', args: []);
  }

  /// `Cancel`
  String get write_confirm_cancel {
    return Intl.message(
      'Cancel',
      name: 'write_confirm_cancel',
      desc: 'Closes the confirmation sheet without running the statement.',
      args: [],
    );
  }

  /// `This statement is too large to run. Shorten it and try again.`
  String get error_studio_statement_too_large {
    return Intl.message(
      'This statement is too large to run. Shorten it and try again.',
      name: 'error_studio_statement_too_large',
      desc: 'The statement is longer than the engine or the phone accepts.',
      args: [],
    );
  }

  /// `Too many places to search. Pick object kinds to narrow the search.`
  String get error_studio_search_pair_limit {
    return Intl.message(
      'Too many places to search. Pick object kinds to narrow the search.',
      name: 'error_studio_search_pair_limit',
      desc: 'Studio refused an object search that would walk too many container and kind pairs; picking kinds narrows it.',
      args: [],
    );
  }

  /// `Studio does not answer. Try again in a moment.`
  String get error_studio_unreachable {
    return Intl.message(
      'Studio does not answer. Try again in a moment.',
      name: 'error_studio_unreachable',
      desc: 'Studio answered a 5xx without its error code, or the connection to it failed.',
      args: [],
    );
  }

  /// `Platform mode is not available in this build of the app. Sign in through Studio.`
  String get error_platform_not_configured {
    return Intl.message(
      'Platform mode is not available in this build of the app. Sign in through Studio.',
      name: 'error_platform_not_configured',
      desc: '',
      args: [],
    );
  }

  /// `This account is not a Platform admin. Sign in through Studio instead.`
  String get error_platform_admin_role_required {
    return Intl.message(
      'This account is not a Platform admin. Sign in through Studio instead.',
      name: 'error_platform_admin_role_required',
      desc: '',
      args: [],
    );
  }

  /// `Platform did not accept this sign-in. Ask an administrator to check that this app is set up for Platform, or sign in to Studio.`
  String get error_platform_account_refused {
    return Intl.message(
      'Platform did not accept this sign-in. Ask an administrator to check that this app is set up for Platform, or sign in to Studio.',
      name: 'error_platform_account_refused',
      desc: '',
      args: [],
    );
  }

  /// `The Platform license has no free admin seat for this account.`
  String get error_platform_license_admin_seats {
    return Intl.message(
      'The Platform license has no free admin seat for this account.',
      name: 'error_platform_license_admin_seats',
      desc: '',
      args: [],
    );
  }

  /// `The Platform license has no free user seat for this grant.`
  String get error_platform_license_user_seats {
    return Intl.message(
      'The Platform license has no free user seat for this grant.',
      name: 'error_platform_license_user_seats',
      desc: '',
      args: [],
    );
  }

  /// `The Platform license has expired.`
  String get error_platform_license_expired {
    return Intl.message(
      'The Platform license has expired.',
      name: 'error_platform_license_expired',
      desc: '',
      args: [],
    );
  }

  /// `The Platform license is not valid.`
  String get error_platform_license_invalid {
    return Intl.message(
      'The Platform license is not valid.',
      name: 'error_platform_license_invalid',
      desc: '',
      args: [],
    );
  }

  /// `This Platform install does not accept the mobile app.`
  String get error_platform_api_disabled {
    return Intl.message(
      'This Platform install does not accept the mobile app.',
      name: 'error_platform_api_disabled',
      desc: '',
      args: [],
    );
  }

  /// `Platform no longer has this item.`
  String get error_platform_not_found {
    return Intl.message('Platform no longer has this item.', name: 'error_platform_not_found', desc: '', args: []);
  }

  /// `Write access needs a connection with a write credential.`
  String get error_platform_grant_level_refused {
    return Intl.message(
      'Write access needs a connection with a write credential.',
      name: 'error_platform_grant_level_refused',
      desc: '',
      args: [],
    );
  }

  /// `Keycloak does not know this user, or has disabled it.`
  String get error_platform_grant_subject_refused {
    return Intl.message(
      'Keycloak does not know this user, or has disabled it.',
      name: 'error_platform_grant_subject_refused',
      desc: '',
      args: [],
    );
  }

  /// `The expiry must be in the future.`
  String get error_platform_grant_expiry_refused {
    return Intl.message(
      'The expiry must be in the future.',
      name: 'error_platform_grant_expiry_refused',
      desc: '',
      args: [],
    );
  }

  /// `Platform did not accept the request.`
  String get error_platform_validation_failed {
    return Intl.message(
      'Platform did not accept the request.',
      name: 'error_platform_validation_failed',
      desc: '',
      args: [],
    );
  }

  /// `Platform cannot reach the identity provider right now. Try again in a moment.`
  String get error_platform_identity_provider_unavailable {
    return Intl.message(
      'Platform cannot reach the identity provider right now. Try again in a moment.',
      name: 'error_platform_identity_provider_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `Platform cannot read the user directory right now. Try again in a moment.`
  String get error_platform_directory_unavailable {
    return Intl.message(
      'Platform cannot read the user directory right now. Try again in a moment.',
      name: 'error_platform_directory_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `Platform cannot reach Keycloak right now. Try again in a moment.`
  String get error_platform_keycloak_unavailable {
    return Intl.message(
      'Platform cannot reach Keycloak right now. Try again in a moment.',
      name: 'error_platform_keycloak_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `The plan of this Platform install does not include this feature.`
  String get error_platform_plan_feature_required {
    return Intl.message(
      'The plan of this Platform install does not include this feature.',
      name: 'error_platform_plan_feature_required',
      desc: '',
      args: [],
    );
  }

  /// `Platform does not allow this account to do this.`
  String get error_platform_permission_denied {
    return Intl.message(
      'Platform does not allow this account to do this.',
      name: 'error_platform_permission_denied',
      desc: '',
      args: [],
    );
  }

  /// `Platform could not complete the request. Try again later.`
  String get error_platform_internal_error {
    return Intl.message(
      'Platform could not complete the request. Try again later.',
      name: 'error_platform_internal_error',
      desc: '',
      args: [],
    );
  }

  /// `Platform does not answer. Try again in a moment.`
  String get error_platform_unreachable {
    return Intl.message(
      'Platform does not answer. Try again in a moment.',
      name: 'error_platform_unreachable',
      desc: 'Platform answered a 5xx without its error code, as the edge in front of a stopped Platform does, or the connection to it failed.',
      args: [],
    );
  }

  /// `Platform sent an answer this app cannot read. The app may need an update.`
  String get error_platform_unreadable_answer {
    return Intl.message(
      'Platform sent an answer this app cannot read. The app may need an update.',
      name: 'error_platform_unreadable_answer',
      desc: '',
      args: [],
    );
  }

  /// `Your account has no Studio role, so it cannot ask for access.`
  String get error_platform_studio_role_required {
    return Intl.message(
      'Your account has no Studio role, so it cannot ask for access.',
      name: 'error_platform_studio_role_required',
      desc: 'Platform refused an access request because the account\'s token carries no Studio role.',
      args: [],
    );
  }

  /// `Access requests are turned off on this installation.`
  String get error_platform_access_requests_disabled {
    return Intl.message(
      'Access requests are turned off on this installation.',
      name: 'error_platform_access_requests_disabled',
      desc: '',
      args: [],
    );
  }

  /// `You already have an open request for this connection.`
  String get error_platform_access_request_pending {
    return Intl.message(
      'You already have an open request for this connection.',
      name: 'error_platform_access_request_pending',
      desc: '',
      args: [],
    );
  }

  /// `You already have this access.`
  String get error_platform_access_already_granted {
    return Intl.message(
      'You already have this access.',
      name: 'error_platform_access_already_granted',
      desc: '',
      args: [],
    );
  }

  /// `You have too many open requests. Wait for an answer or withdraw one.`
  String get error_platform_access_request_limit {
    return Intl.message(
      'You have too many open requests. Wait for an answer or withdraw one.',
      name: 'error_platform_access_request_limit',
      desc: '',
      args: [],
    );
  }

  /// `This request was already answered or withdrawn.`
  String get error_platform_access_request_decided {
    return Intl.message(
      'This request was already answered or withdrawn.',
      name: 'error_platform_access_request_decided',
      desc: '',
      args: [],
    );
  }

  /// `Write a reason of at most 500 characters.`
  String get error_platform_access_request_reason_refused {
    return Intl.message(
      'Write a reason of at most 500 characters.',
      name: 'error_platform_access_request_reason_refused',
      desc: 'Platform refused an access request create or refuse on the reason field alone.',
      args: [],
    );
  }

  /// `Type one or more statements`
  String get sql_editor_hint {
    return Intl.message(
      'Type one or more statements',
      name: 'sql_editor_hint',
      desc: 'The hint of the empty SQL editor, which runs one statement or a script.',
      args: [],
    );
  }

  /// `Statement`
  String get sql_editor_field_label {
    return Intl.message(
      'Statement',
      name: 'sql_editor_field_label',
      desc: 'The accessible name of the SQL editor\'s text field.',
      args: [],
    );
  }

  /// `Run`
  String get sql_editor_run {
    return Intl.message('Run', name: 'sql_editor_run', desc: 'Runs the statement in the SQL editor.', args: []);
  }

  /// `This statement left a transaction open, and Studio rolled it back, so its changes were discarded. Add {keyword} to keep them.`
  String sql_editor_rolled_back(String keyword) {
    return Intl.message(
      'This statement left a transaction open, and Studio rolled it back, so its changes were discarded. Add $keyword to keep them.',
      name: 'sql_editor_rolled_back',
      desc: 'The SQL editor\'s notice that Studio rolled back a transaction the statement left open, with the engine\'s commit keyword.',
      args: [keyword],
    );
  }

  /// `Cancel`
  String get sql_editor_cancel {
    return Intl.message(
      'Cancel',
      name: 'sql_editor_cancel',
      desc: 'Asks Studio to stop the statement that runs, shown on Run while it runs.',
      args: [],
    );
  }

  /// `Stop waiting`
  String get sql_editor_stop_waiting {
    return Intl.message(
      'Stop waiting',
      name: 'sql_editor_stop_waiting',
      desc:
          'Shown on Run while a statement runs on an engine that cannot cancel: the app stops waiting for the answer.',
      args: [],
    );
  }

  /// `Cancelling`
  String get sql_editor_cancelling {
    return Intl.message(
      'Cancelling',
      name: 'sql_editor_cancelling',
      desc: 'Shown on Run while Studio is asked to stop the statement.',
      args: [],
    );
  }

  /// `Cancelled`
  String get sql_editor_cancelled {
    return Intl.message(
      'Cancelled',
      name: 'sql_editor_cancelled',
      desc: 'The SQL editor\'s notice that Studio stopped the statement; not an error.',
      args: [],
    );
  }

  /// `Studio could not confirm the cancel. The statement may still run on the server.`
  String get sql_editor_cancel_not_confirmed {
    return Intl.message(
      'Studio could not confirm the cancel. The statement may still run on the server.',
      name: 'sql_editor_cancel_not_confirmed',
      desc: 'The SQL editor\'s notice that Studio did not confirm the cancel, so the statement may still run.',
      args: [],
    );
  }

  /// `Stopped waiting. This database cannot cancel a statement, so it may still run on the server.`
  String get sql_editor_stopped_waiting {
    return Intl.message(
      'Stopped waiting. This database cannot cancel a statement, so it may still run on the server.',
      name: 'sql_editor_stopped_waiting',
      desc: 'The SQL editor\'s notice after Stop waiting, on an engine that cannot cancel.',
      args: [],
    );
  }

  /// `The run was interrupted when the app went to the background; Studio cancelled it.`
  String get sql_editor_interrupted_read {
    return Intl.message(
      'The run was interrupted when the app went to the background; Studio cancelled it.',
      name: 'sql_editor_interrupted_read',
      desc: 'The SQL editor\'s notice that a read was interrupted because the app went to the background, and Studio cancelled it.',
      args: [],
    );
  }

  /// `Outcome unknown: check the data before running it again.`
  String get sql_editor_interrupted_unknown {
    return Intl.message(
      'Outcome unknown: check the data before running it again.',
      name: 'sql_editor_interrupted_unknown',
      desc: 'The SQL editor\'s notice that a statement that may write was interrupted while the app was in the background, so whether it ran is unknown.',
      args: [],
    );
  }

  /// `Run again`
  String get sql_editor_run_again {
    return Intl.message(
      'Run again',
      name: 'sql_editor_run_again',
      desc: 'Runs the interrupted read again, shown under its notice; never offered for a statement that may write.',
      args: [],
    );
  }

  /// `Database`
  String get sql_editor_catalog_label {
    return Intl.message(
      'Database',
      name: 'sql_editor_catalog_label',
      desc: 'The SQL editor\'s name for the database a server-level connection runs statements in, when Studio sends no label for its level.',
      args: [],
    );
  }

  /// `{label}: {catalog}`
  String sql_editor_catalog_chip(String label, String catalog) {
    return Intl.message(
      '$label: $catalog',
      name: 'sql_editor_catalog_chip',
      desc: 'The SQL editor\'s chip of the database a server-level connection runs statements in, which opens the picker.',
      args: [label, catalog],
    );
  }

  /// `Run statements in`
  String get sql_editor_catalog_picker_title {
    return Intl.message(
      'Run statements in',
      name: 'sql_editor_catalog_picker_title',
      desc: 'The title of the SQL editor\'s picker of the database a server-level connection runs statements in.',
      args: [],
    );
  }

  /// `The databases to run statements in could not be listed.`
  String get sql_editor_catalog_failed {
    return Intl.message(
      'The databases to run statements in could not be listed.',
      name: 'sql_editor_catalog_failed',
      desc: 'The SQL editor could not read the databases of a server-level connection, shown above Studio\'s error with its retry; Run waits for a database.',
      args: [],
    );
  }

  /// `The server lists no database to run statements in.`
  String get sql_editor_catalog_none {
    return Intl.message(
      'The server lists no database to run statements in.',
      name: 'sql_editor_catalog_none',
      desc: 'A server-level connection lists no database, so the SQL editor offers no Run.',
      args: [],
    );
  }

  /// `History`
  String get sql_history_open {
    return Intl.message(
      'History',
      name: 'sql_history_open',
      desc: 'Opens the statement history of this phone from the SQL editor.',
      args: [],
    );
  }

  /// `History`
  String get sql_history_title {
    return Intl.message('History', name: 'sql_history_title', desc: 'Title of the statement history sheet.', args: []);
  }

  /// `All connections`
  String get sql_history_all_connections {
    return Intl.message(
      'All connections',
      name: 'sql_history_all_connections',
      desc: 'Switch on the history sheet that shows the entries of every connection, not only the open one.',
      args: [],
    );
  }

  /// `Search statements and connections`
  String get sql_history_search_hint {
    return Intl.message(
      'Search statements and connections',
      name: 'sql_history_search_hint',
      desc: 'Hint of the history sheet\'s search field, which searches the statement text and the connection name on the phone.',
      args: [],
    );
  }

  /// `All`
  String get sql_history_filter_all {
    return Intl.message(
      'All',
      name: 'sql_history_filter_all',
      desc: 'Status filter of the history sheet: every run.',
      args: [],
    );
  }

  /// `Succeeded`
  String get sql_history_filter_success {
    return Intl.message(
      'Succeeded',
      name: 'sql_history_filter_success',
      desc: 'Status filter of the history sheet: only the runs that succeeded.',
      args: [],
    );
  }

  /// `Failed`
  String get sql_history_filter_failure {
    return Intl.message(
      'Failed',
      name: 'sql_history_filter_failure',
      desc: 'Status filter of the history sheet: only the runs that failed.',
      args: [],
    );
  }

  /// `Succeeded`
  String get sql_history_succeeded {
    return Intl.message(
      'Succeeded',
      name: 'sql_history_succeeded',
      desc: 'Status of a history entry whose run succeeded.',
      args: [],
    );
  }

  /// `Failed`
  String get sql_history_failed {
    return Intl.message(
      'Failed',
      name: 'sql_history_failed',
      desc: 'Status of a history entry whose run failed; the database\'s words are never kept.',
      args: [],
    );
  }

  /// `Too long to keep`
  String get sql_history_too_long {
    return Intl.message(
      'Too long to keep',
      name: 'sql_history_too_long',
      desc: 'Shown in place of a history entry\'s statement that was too long to keep on the phone.',
      args: [],
    );
  }

  /// `{count, plural, =1{1 row} other{{count} rows}}`
  String sql_history_rows(int count) {
    return Intl.plural(
      count,
      one: '1 row',
      other: '$count rows',
      name: 'sql_history_rows',
      desc: 'The rows a history entry\'s run counted.',
      args: [count],
    );
  }

  /// `{milliseconds} ms`
  String sql_history_duration(int milliseconds) {
    return Intl.message(
      '$milliseconds ms',
      name: 'sql_history_duration',
      desc: 'How long a history entry\'s run took.',
      args: [milliseconds],
    );
  }

  /// `Delete`
  String get sql_history_delete {
    return Intl.message(
      'Delete',
      name: 'sql_history_delete',
      desc: 'Deletes one history entry; also the swipe\'s label.',
      args: [],
    );
  }

  /// `Clear all`
  String get sql_history_clear_all {
    return Intl.message(
      'Clear all',
      name: 'sql_history_clear_all',
      desc: 'Deletes the whole statement history of this account on the phone, after a confirmation.',
      args: [],
    );
  }

  /// `Clear the history?`
  String get sql_history_clear_title {
    return Intl.message(
      'Clear the history?',
      name: 'sql_history_clear_title',
      desc: 'Title of the confirmation before the whole history is deleted.',
      args: [],
    );
  }

  /// `Every statement in your history on this phone is deleted. This cannot be undone.`
  String get sql_history_clear_message {
    return Intl.message(
      'Every statement in your history on this phone is deleted. This cannot be undone.',
      name: 'sql_history_clear_message',
      desc: 'Body of the confirmation before the whole history is deleted.',
      args: [],
    );
  }

  /// `No statements yet`
  String get sql_history_empty {
    return Intl.message(
      'No statements yet',
      name: 'sql_history_empty',
      desc: 'Empty state of the history sheet.',
      args: [],
    );
  }

  /// `Statements you run appear here. They stay on this phone.`
  String get sql_history_empty_description {
    return Intl.message(
      'Statements you run appear here. They stay on this phone.',
      name: 'sql_history_empty_description',
      desc: 'Description under the empty state of the history sheet.',
      args: [],
    );
  }

  /// `Replace the editor's text?`
  String get sql_history_replace_title {
    return Intl.message(
      'Replace the editor\'s text?',
      name: 'sql_history_replace_title',
      desc: 'Title of the prompt before a statement opened in the editor (from the history or another screen) replaces its text.',
      args: [],
    );
  }

  /// `The new statement takes the place of the text in the editor. It does not run.`
  String get editor_replace_message {
    return Intl.message(
      'The new statement takes the place of the text in the editor. It does not run.',
      name: 'editor_replace_message',
      desc: 'Body of the prompt before a statement opened in the editor (from the history or another screen) replaces its text.',
      args: [],
    );
  }

  /// `Replace`
  String get sql_history_replace {
    return Intl.message(
      'Replace',
      name: 'sql_history_replace',
      desc: 'Confirms that a statement opened in the editor (from the history or another screen) replaces its text.',
      args: [],
    );
  }

  /// `Run selection`
  String get sql_editor_run_selection {
    return Intl.message(
      'Run selection',
      name: 'sql_editor_run_selection',
      desc: 'Runs only the text selected in the SQL editor, shown on Run while a non-blank selection exists.',
      args: [],
    );
  }

  /// `Running for {time}`
  String sql_editor_script_elapsed(String time) {
    return Intl.message(
      'Running for $time',
      name: 'sql_editor_script_elapsed',
      desc: 'The time a script has run so far, in minutes and seconds.',
      args: [time],
    );
  }

  /// `Statement {number}`
  String sql_editor_script_statement(int number) {
    return Intl.message(
      'Statement $number',
      name: 'sql_editor_script_statement',
      desc: 'The title of a script statement\'s card, numbered from 1.',
      args: [number],
    );
  }

  /// `Succeeded`
  String get sql_editor_script_succeeded {
    return Intl.message(
      'Succeeded',
      name: 'sql_editor_script_succeeded',
      desc: 'A script statement that ran without an error.',
      args: [],
    );
  }

  /// `Failed`
  String get sql_editor_script_failed {
    return Intl.message(
      'Failed',
      name: 'sql_editor_script_failed',
      desc: 'A script statement the database refused.',
      args: [],
    );
  }

  /// `{time} ms`
  String sql_editor_script_failed_time(String time) {
    return Intl.message(
      '$time ms',
      name: 'sql_editor_script_failed_time',
      desc: 'The time a failed script statement took, in milliseconds.',
      args: [time],
    );
  }

  /// `{count, plural, =1{1 statement not run} other{{count} statements not run}}`
  String sql_editor_script_not_run(int count) {
    return Intl.plural(
      count,
      one: '1 statement not run',
      other: '$count statements not run',
      name: 'sql_editor_script_not_run',
      desc: 'The statements of a script Studio did not run after a failure.',
      args: [count],
    );
  }

  /// `Show rows`
  String get sql_editor_script_show_rows {
    return Intl.message(
      'Show rows',
      name: 'sql_editor_script_show_rows',
      desc: 'The accessible action of a script statement\'s card, which shows its rows.',
      args: [],
    );
  }

  /// `The script left a transaction open, and Studio rolled it back, so its changes were discarded.`
  String get sql_editor_script_rolled_back {
    return Intl.message(
      'The script left a transaction open, and Studio rolled it back, so its changes were discarded.',
      name: 'sql_editor_script_rolled_back',
      desc: 'Studio rolled back a transaction a failed script left open; nothing complete is left to keep.',
      args: [],
    );
  }

  /// `The script left a transaction open, and Studio rolled it back, so its changes were discarded. Add {keyword} to keep them.`
  String sql_editor_script_rolled_back_keep(String keyword) {
    return Intl.message(
      'The script left a transaction open, and Studio rolled it back, so its changes were discarded. Add $keyword to keep them.',
      name: 'sql_editor_script_rolled_back_keep',
      desc: 'Studio rolled back a transaction a script left open after every statement succeeded, with the engine\'s commit keyword.',
      args: [keyword],
    );
  }

  /// `Tab`
  String get sql_editor_tab {
    return Intl.message(
      'Tab',
      name: 'sql_editor_tab',
      desc: 'Tooltip of the editor\'s accessory button that inserts two spaces at the cursor.',
      args: [],
    );
  }

  /// `Undo`
  String get sql_editor_undo {
    return Intl.message(
      'Undo',
      name: 'sql_editor_undo',
      desc: 'Tooltip of the editor\'s accessory button that undoes the last edit.',
      args: [],
    );
  }

  /// `Redo`
  String get sql_editor_redo {
    return Intl.message(
      'Redo',
      name: 'sql_editor_redo',
      desc: 'Tooltip of the editor\'s accessory button that redoes the edit last undone.',
      args: [],
    );
  }

  /// `Language: {language}`
  String sql_editor_language(String language) {
    return Intl.message(
      'Language: $language',
      name: 'sql_editor_language',
      desc: 'The small label that names the statement language of the connection\'s engine, as Studio names it, such as sql or redis.',
      args: [language],
    );
  }

  /// `The language of this connection could not be read, so the text is not highlighted. {reason}`
  String sql_editor_language_unknown(String reason) {
    return Intl.message(
      'The language of this connection could not be read, so the text is not highlighted. $reason',
      name: 'sql_editor_language_unknown',
      desc: 'Shown in place of the language label when Studio did not answer the engine\'s meta, with the reason.',
      args: [reason],
    );
  }

  /// `This text is longer than 100,000 characters, so it is not kept on this phone, and the text saved earlier for this connection was removed.`
  String get sql_editor_draft_not_kept {
    return Intl.message(
      'This text is longer than 100,000 characters, so it is not kept on this phone, and the text saved earlier for this connection was removed.',
      name: 'sql_editor_draft_not_kept',
      desc: 'Said once when the editor\'s text is over the bound of a saved draft.',
      args: [],
    );
  }

  /// `The text could not be saved on this phone. {reason}`
  String sql_editor_draft_not_saved(String reason) {
    return Intl.message(
      'The text could not be saved on this phone. $reason',
      name: 'sql_editor_draft_not_saved',
      desc: 'Shown when the device refused to save the editor\'s draft, with the reason.',
      args: [reason],
    );
  }

  /// `New text is not kept until you discard the saved text.`
  String get sql_editor_draft_unreadable_note {
    return Intl.message(
      'New text is not kept until you discard the saved text.',
      name: 'sql_editor_draft_unreadable_note',
      desc: 'Shown under the unreadable saved draft message: the editor keeps no new text until the user discards it.',
      args: [],
    );
  }

  /// `The text saved for this connection could not be read, so new text is not kept. {reason}`
  String sql_editor_draft_read_failed(String reason) {
    return Intl.message(
      'The text saved for this connection could not be read, so new text is not kept. $reason',
      name: 'sql_editor_draft_read_failed',
      desc:
          'Shown when reading the editor\'s saved draft failed for a reason other than an unreadable file, with Retry.',
      args: [reason],
    );
  }

  /// `Text is not kept until Studio names your account.`
  String get sql_editor_draft_no_account {
    return Intl.message(
      'Text is not kept until Studio names your account.',
      name: 'sql_editor_draft_no_account',
      desc: 'Shown under the editor\'s field while Studio has not named the signed-in account: the field stays editable, but no draft is read or kept.',
      args: [],
    );
  }

  /// `That connection is no longer available, so the statement was not opened.`
  String get editor_open_connection_unavailable {
    return Intl.message(
      'That connection is no longer available, so the statement was not opened.',
      name: 'editor_open_connection_unavailable',
      desc: 'Shown when a statement was to open in the editor on a connection Studio no longer lists; nothing opens.',
      args: [],
    );
  }

  /// `The server does not list the database {catalog}, so the editor uses {used}.`
  String editor_catalog_not_listed(String catalog, String used) {
    return Intl.message(
      'The server does not list the database $catalog, so the editor uses $used.',
      name: 'editor_catalog_not_listed',
      desc: 'Shown when a statement opened in the editor names a database the server does not list; the editor runs in the default it names instead.',
      args: [catalog, used],
    );
  }

  /// `The server does not list the database {catalog}.`
  String editor_catalog_not_listed_none(String catalog) {
    return Intl.message(
      'The server does not list the database $catalog.',
      name: 'editor_catalog_not_listed_none',
      desc: 'Shown when a statement opened in the editor names a database the server does not list, and the server lists none to use instead.',
      args: [catalog],
    );
  }

  /// `Privacy`
  String get settings_privacy {
    return Intl.message('Privacy', name: 'settings_privacy', desc: '', args: []);
  }

  /// `Remove my data`
  String get remove_my_data {
    return Intl.message('Remove my data', name: 'remove_my_data', desc: '', args: []);
  }

  /// `Remove what this app keeps about you on this phone, then sign out`
  String get remove_my_data_subtitle {
    return Intl.message(
      'Remove what this app keeps about you on this phone, then sign out',
      name: 'remove_my_data_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `Remove my data?`
  String get remove_my_data_title {
    return Intl.message('Remove my data?', name: 'remove_my_data_title', desc: '', args: []);
  }

  /// `Removed from this phone`
  String get remove_my_data_removed {
    return Intl.message('Removed from this phone', name: 'remove_my_data_removed', desc: '', args: []);
  }

  /// `SQL editor drafts`
  String get remove_my_data_drafts {
    return Intl.message('SQL editor drafts', name: 'remove_my_data_drafts', desc: '', args: []);
  }

  /// `Statement history`
  String get remove_my_data_history {
    return Intl.message('Statement history', name: 'remove_my_data_history', desc: '', args: []);
  }

  /// `Starred connections`
  String get remove_my_data_favorites {
    return Intl.message('Starred connections', name: 'remove_my_data_favorites', desc: '', args: []);
  }

  /// `Recent connections`
  String get remove_my_data_recents {
    return Intl.message('Recent connections', name: 'remove_my_data_recents', desc: '', args: []);
  }

  /// `The last open connection and database`
  String get remove_my_data_last_connection {
    return Intl.message(
      'The last open connection and database',
      name: 'remove_my_data_last_connection',
      desc: '',
      args: [],
    );
  }

  /// `Collapsed sections of the connection list`
  String get remove_my_data_collapsed_sections {
    return Intl.message(
      'Collapsed sections of the connection list',
      name: 'remove_my_data_collapsed_sections',
      desc: '',
      args: [],
    );
  }

  /// `Kept on this phone`
  String get remove_my_data_kept {
    return Intl.message('Kept on this phone', name: 'remove_my_data_kept', desc: '', args: []);
  }

  /// `Language, theme, result view and app lock`
  String get remove_my_data_kept_preferences {
    return Intl.message(
      'Language, theme, result view and app lock',
      name: 'remove_my_data_kept_preferences',
      desc: '',
      args: [],
    );
  }

  /// `You are signed out once your data is removed.`
  String get remove_my_data_signs_out {
    return Intl.message(
      'You are signed out once your data is removed.',
      name: 'remove_my_data_signs_out',
      desc: '',
      args: [],
    );
  }

  /// `Remove and sign out`
  String get remove_my_data_confirm {
    return Intl.message('Remove and sign out', name: 'remove_my_data_confirm', desc: '', args: []);
  }

  /// `Some of your data could not be removed from this phone, so you are still signed in.`
  String get error_settings_user_data_not_removed {
    return Intl.message(
      'Some of your data could not be removed from this phone, so you are still signed in.',
      name: 'error_settings_user_data_not_removed',
      desc: '',
      args: [],
    );
  }

  /// `Security`
  String get settings_security {
    return Intl.message('Security', name: 'settings_security', desc: '', args: []);
  }

  /// `App lock`
  String get app_lock {
    return Intl.message('App lock', name: 'app_lock', desc: '', args: []);
  }

  /// `Ask for your fingerprint, face or screen lock when the app opens`
  String get app_lock_subtitle {
    return Intl.message(
      'Ask for your fingerprint, face or screen lock when the app opens',
      name: 'app_lock_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `Required by your organization`
  String get app_lock_required_subtitle {
    return Intl.message('Required by your organization', name: 'app_lock_required_subtitle', desc: '', args: []);
  }

  /// `Set a screen lock on this device to turn this on`
  String get app_lock_no_screen_lock_subtitle {
    return Intl.message(
      'Set a screen lock on this device to turn this on',
      name: 'app_lock_no_screen_lock_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `Lock after`
  String get app_lock_timeout {
    return Intl.message('Lock after', name: 'app_lock_timeout', desc: '', args: []);
  }

  /// `Immediately`
  String get app_lock_timeout_immediately {
    return Intl.message('Immediately', name: 'app_lock_timeout_immediately', desc: '', args: []);
  }

  /// `1 minute in the background`
  String get app_lock_timeout_one_minute {
    return Intl.message('1 minute in the background', name: 'app_lock_timeout_one_minute', desc: '', args: []);
  }

  /// `5 minutes in the background`
  String get app_lock_timeout_five_minutes {
    return Intl.message('5 minutes in the background', name: 'app_lock_timeout_five_minutes', desc: '', args: []);
  }

  /// `15 minutes in the background`
  String get app_lock_timeout_fifteen_minutes {
    return Intl.message('15 minutes in the background', name: 'app_lock_timeout_fifteen_minutes', desc: '', args: []);
  }

  /// `Confirm it is you to turn on the app lock`
  String get app_lock_enable_reason {
    return Intl.message(
      'Confirm it is you to turn on the app lock',
      name: 'app_lock_enable_reason',
      desc: '',
      args: [],
    );
  }

  /// `LibreDB is locked`
  String get app_lock_locked_title {
    return Intl.message('LibreDB is locked', name: 'app_lock_locked_title', desc: '', args: []);
  }

  /// `Unlock with your screen lock to continue.`
  String get app_lock_locked_message {
    return Intl.message(
      'Unlock with your screen lock to continue.',
      name: 'app_lock_locked_message',
      desc: '',
      args: [],
    );
  }

  /// `Unlock with your face or screen lock to continue.`
  String get app_lock_locked_message_face {
    return Intl.message(
      'Unlock with your face or screen lock to continue.',
      name: 'app_lock_locked_message_face',
      desc: '',
      args: [],
    );
  }

  /// `Unlock with your fingerprint or screen lock to continue.`
  String get app_lock_locked_message_fingerprint {
    return Intl.message(
      'Unlock with your fingerprint or screen lock to continue.',
      name: 'app_lock_locked_message_fingerprint',
      desc: '',
      args: [],
    );
  }

  /// `Unlock with your iris or screen lock to continue.`
  String get app_lock_locked_message_iris {
    return Intl.message(
      'Unlock with your iris or screen lock to continue.',
      name: 'app_lock_locked_message_iris',
      desc: '',
      args: [],
    );
  }

  /// `Unlock with your biometrics or screen lock to continue.`
  String get app_lock_locked_message_several {
    return Intl.message(
      'Unlock with your biometrics or screen lock to continue.',
      name: 'app_lock_locked_message_several',
      desc: '',
      args: [],
    );
  }

  /// `Unlock`
  String get app_lock_unlock {
    return Intl.message('Unlock', name: 'app_lock_unlock', desc: '', args: []);
  }

  /// `Unlock LibreDB`
  String get app_lock_prompt_reason {
    return Intl.message('Unlock LibreDB', name: 'app_lock_prompt_reason', desc: '', args: []);
  }

  /// `Not recognized. Try again.`
  String get app_lock_failed {
    return Intl.message('Not recognized. Try again.', name: 'app_lock_failed', desc: '', args: []);
  }

  /// `Too many attempts. Try again later.`
  String get app_lock_locked_out {
    return Intl.message('Too many attempts. Try again later.', name: 'app_lock_locked_out', desc: '', args: []);
  }

  /// `Set a screen lock on this device to use LibreDB, or sign out.`
  String get app_lock_no_screen_lock {
    return Intl.message(
      'Set a screen lock on this device to use LibreDB, or sign out.',
      name: 'app_lock_no_screen_lock',
      desc: '',
      args: [],
    );
  }

  /// `The app lock setting could not be saved.`
  String get error_settings_app_lock_not_saved {
    return Intl.message(
      'The app lock setting could not be saved.',
      name: 'error_settings_app_lock_not_saved',
      desc: '',
      args: [],
    );
  }

  /// `LibreDB could not check this device's screen lock. Try Unlock again, or sign out.`
  String get app_lock_check_failed {
    return Intl.message(
      'LibreDB could not check this device\'s screen lock. Try Unlock again, or sign out.',
      name: 'app_lock_check_failed',
      desc: '',
      args: [],
    );
  }

  /// `Could not load the connections`
  String get platform_connections_load_failed {
    return Intl.message('Could not load the connections', name: 'platform_connections_load_failed', desc: '', args: []);
  }

  /// `Filter by name or engine`
  String get platform_connections_filter_hint {
    return Intl.message('Filter by name or engine', name: 'platform_connections_filter_hint', desc: '', args: []);
  }

  /// `This install has no connections yet`
  String get platform_connections_empty_title {
    return Intl.message(
      'This install has no connections yet',
      name: 'platform_connections_empty_title',
      desc: '',
      args: [],
    );
  }

  /// `Connections are added in the Platform web console.`
  String get platform_connections_empty_description {
    return Intl.message(
      'Connections are added in the Platform web console.',
      name: 'platform_connections_empty_description',
      desc: '',
      args: [],
    );
  }

  /// `No connection matches the filter`
  String get platform_connections_search_empty_title {
    return Intl.message(
      'No connection matches the filter',
      name: 'platform_connections_search_empty_title',
      desc: '',
      args: [],
    );
  }

  /// `Try another name or engine.`
  String get platform_connections_search_empty_description {
    return Intl.message(
      'Try another name or engine.',
      name: 'platform_connections_search_empty_description',
      desc: '',
      args: [],
    );
  }

  /// `Unknown status`
  String get platform_connections_status_unknown {
    return Intl.message('Unknown status', name: 'platform_connections_status_unknown', desc: '', args: []);
  }

  /// `Read grants only`
  String get platform_connections_read_grants_only {
    return Intl.message('Read grants only', name: 'platform_connections_read_grants_only', desc: '', args: []);
  }

  /// `This connection has no write credential, so only read access can be granted.`
  String get platform_connections_read_grants_only_semantics {
    return Intl.message(
      'This connection has no write credential, so only read access can be granted.',
      name: 'platform_connections_read_grants_only_semantics',
      desc: '',
      args: [],
    );
  }

  /// `Could not refresh the connections`
  String get platform_connections_refresh_failed {
    return Intl.message(
      'Could not refresh the connections',
      name: 'platform_connections_refresh_failed',
      desc: '',
      args: [],
    );
  }

  /// `Connection actions`
  String get platform_connections_active_actions {
    return Intl.message('Connection actions', name: 'platform_connections_active_actions', desc: '', args: []);
  }

  /// `Disable connection`
  String get platform_connections_active_disable {
    return Intl.message('Disable connection', name: 'platform_connections_active_disable', desc: '', args: []);
  }

  /// `Enable connection`
  String get platform_connections_active_enable {
    return Intl.message('Enable connection', name: 'platform_connections_active_enable', desc: '', args: []);
  }

  /// `{connection} closes for every Studio user within about 30 seconds. Queries already running are not stopped. Its grants are kept.`
  String platform_connections_active_disable_message(String connection) {
    return Intl.message(
      '$connection closes for every Studio user within about 30 seconds. Queries already running are not stopped. Its grants are kept.',
      name: 'platform_connections_active_disable_message',
      desc: '',
      args: [connection],
    );
  }

  /// `{connection} opens again for everyone who holds a grant on it. Those grants can take user seats of the license.`
  String platform_connections_active_enable_message(String connection) {
    return Intl.message(
      '$connection opens again for everyone who holds a grant on it. Those grants can take user seats of the license.',
      name: 'platform_connections_active_enable_message',
      desc: '',
      args: [connection],
    );
  }

  /// `Disable`
  String get platform_connections_active_disable_confirm {
    return Intl.message('Disable', name: 'platform_connections_active_disable_confirm', desc: '', args: []);
  }

  /// `Enable`
  String get platform_connections_active_enable_confirm {
    return Intl.message('Enable', name: 'platform_connections_active_enable_confirm', desc: '', args: []);
  }

  /// `Connection disabled`
  String get platform_connections_active_disabled {
    return Intl.message('Connection disabled', name: 'platform_connections_active_disabled', desc: '', args: []);
  }

  /// `Connection enabled`
  String get platform_connections_active_enabled {
    return Intl.message('Connection enabled', name: 'platform_connections_active_enabled', desc: '', args: []);
  }

  /// `This connection no longer exists`
  String get platform_connections_active_gone {
    return Intl.message(
      'This connection no longer exists',
      name: 'platform_connections_active_gone',
      desc: '',
      args: [],
    );
  }

  /// `Not enough user seats`
  String get platform_connections_active_user_seats_title {
    return Intl.message(
      'Not enough user seats',
      name: 'platform_connections_active_user_seats_title',
      desc: '',
      args: [],
    );
  }

  /// `The Platform license does not have enough user seats for the grants of this connection.`
  String get platform_connections_active_user_seats {
    return Intl.message(
      'The Platform license does not have enough user seats for the grants of this connection.',
      name: 'platform_connections_active_user_seats',
      desc: '',
      args: [],
    );
  }

  /// `Could not load your Platform account`
  String get platform_home_identity_load_failed {
    return Intl.message(
      'Could not load your Platform account',
      name: 'platform_home_identity_load_failed',
      desc: '',
      args: [],
    );
  }

  /// `Organization`
  String get platform_home_tenant_label {
    return Intl.message('Organization', name: 'platform_home_tenant_label', desc: '', args: []);
  }

  /// `Signed in as`
  String get platform_home_signed_in_as {
    return Intl.message('Signed in as', name: 'platform_home_signed_in_as', desc: '', args: []);
  }

  /// `Platform admin`
  String get platform_home_admin_label {
    return Intl.message('Platform admin', name: 'platform_home_admin_label', desc: '', args: []);
  }

  /// `Connections`
  String get platform_home_connections_shortcut {
    return Intl.message('Connections', name: 'platform_home_connections_shortcut', desc: '', args: []);
  }

  /// `See every connection of this install.`
  String get platform_home_connections_shortcut_description {
    return Intl.message(
      'See every connection of this install.',
      name: 'platform_home_connections_shortcut_description',
      desc: '',
      args: [],
    );
  }

  /// `Audit`
  String get platform_audit_tab {
    return Intl.message('Audit', name: 'platform_audit_tab', desc: '', args: []);
  }

  /// `Could not load the audit log`
  String get platform_audit_load_failed {
    return Intl.message('Could not load the audit log', name: 'platform_audit_load_failed', desc: '', args: []);
  }

  /// `Could not refresh the audit log`
  String get platform_audit_refresh_failed {
    return Intl.message('Could not refresh the audit log', name: 'platform_audit_refresh_failed', desc: '', args: []);
  }

  /// `Load more`
  String get platform_audit_load_more {
    return Intl.message('Load more', name: 'platform_audit_load_more', desc: '', args: []);
  }

  /// `Could not load more events`
  String get platform_audit_load_more_failed {
    return Intl.message('Could not load more events', name: 'platform_audit_load_more_failed', desc: '', args: []);
  }

  /// `No governed queries yet`
  String get platform_audit_empty_title {
    return Intl.message('No governed queries yet', name: 'platform_audit_empty_title', desc: '', args: []);
  }

  /// `Queries that Studio runs on Platform connections appear here.`
  String get platform_audit_empty_description {
    return Intl.message(
      'Queries that Studio runs on Platform connections appear here.',
      name: 'platform_audit_empty_description',
      desc: '',
      args: [],
    );
  }

  /// `No event matches the filters`
  String get platform_audit_filtered_empty_title {
    return Intl.message(
      'No event matches the filters',
      name: 'platform_audit_filtered_empty_title',
      desc: '',
      args: [],
    );
  }

  /// `Remove a filter or choose another one.`
  String get platform_audit_filtered_empty_description {
    return Intl.message(
      'Remove a filter or choose another one.',
      name: 'platform_audit_filtered_empty_description',
      desc: '',
      args: [],
    );
  }

  /// `Clear filters`
  String get platform_audit_clear_filters {
    return Intl.message('Clear filters', name: 'platform_audit_clear_filters', desc: '', args: []);
  }

  /// `Filters`
  String get platform_audit_filters {
    return Intl.message('Filters', name: 'platform_audit_filters', desc: '', args: []);
  }

  /// `The audit log is not in this install's plan`
  String get platform_audit_plan_refused_title {
    return Intl.message(
      'The audit log is not in this install\'s plan',
      name: 'platform_audit_plan_refused_title',
      desc: '',
      args: [],
    );
  }

  /// `A plan with the audit log is chosen in the Platform license.`
  String get platform_audit_plan_refused_description {
    return Intl.message(
      'A plan with the audit log is chosen in the Platform license.',
      name: 'platform_audit_plan_refused_description',
      desc: '',
      args: [],
    );
  }

  /// `Platform does not let this account read the audit log`
  String get platform_audit_permission_refused_title {
    return Intl.message(
      'Platform does not let this account read the audit log',
      name: 'platform_audit_permission_refused_title',
      desc: '',
      args: [],
    );
  }

  /// `A Platform admin can give this account the audit permission.`
  String get platform_audit_permission_refused_description {
    return Intl.message(
      'A Platform admin can give this account the audit permission.',
      name: 'platform_audit_permission_refused_description',
      desc: '',
      args: [],
    );
  }

  /// `Unknown connection`
  String get platform_audit_unknown_connection {
    return Intl.message('Unknown connection', name: 'platform_audit_unknown_connection', desc: '', args: []);
  }

  /// `Statement not captured`
  String get platform_audit_statement_not_captured {
    return Intl.message('Statement not captured', name: 'platform_audit_statement_not_captured', desc: '', args: []);
  }

  /// `Just now`
  String get platform_audit_time_just_now {
    return Intl.message('Just now', name: 'platform_audit_time_just_now', desc: '', args: []);
  }

  /// `{count} min ago`
  String platform_audit_time_minutes_ago(int count) {
    return Intl.message('$count min ago', name: 'platform_audit_time_minutes_ago', desc: '', args: [count]);
  }

  /// `{count} h ago`
  String platform_audit_time_hours_ago(int count) {
    return Intl.message('$count h ago', name: 'platform_audit_time_hours_ago', desc: '', args: [count]);
  }

  /// `{ms} ms`
  String platform_audit_duration(int ms) {
    return Intl.message('$ms ms', name: 'platform_audit_duration', desc: '', args: [ms]);
  }

  /// `Rows: {count}`
  String platform_audit_row_count(int count) {
    return Intl.message('Rows: $count', name: 'platform_audit_row_count', desc: '', args: [count]);
  }

  /// `Success`
  String get platform_audit_status_success {
    return Intl.message('Success', name: 'platform_audit_status_success', desc: '', args: []);
  }

  /// `Error`
  String get platform_audit_status_error {
    return Intl.message('Error', name: 'platform_audit_status_error', desc: '', args: []);
  }

  /// `Cancelled`
  String get platform_audit_status_cancelled {
    return Intl.message('Cancelled', name: 'platform_audit_status_cancelled', desc: '', args: []);
  }

  /// `Refused`
  String get platform_audit_status_refused {
    return Intl.message('Refused', name: 'platform_audit_status_refused', desc: '', args: []);
  }

  /// `Any`
  String get platform_audit_any {
    return Intl.message('Any', name: 'platform_audit_any', desc: '', args: []);
  }

  /// `Status`
  String get platform_audit_filter_status {
    return Intl.message('Status', name: 'platform_audit_filter_status', desc: '', args: []);
  }

  /// `Statement type`
  String get platform_audit_filter_statement_type {
    return Intl.message('Statement type', name: 'platform_audit_filter_statement_type', desc: '', args: []);
  }

  /// `Source`
  String get platform_audit_filter_source {
    return Intl.message('Source', name: 'platform_audit_filter_source', desc: '', args: []);
  }

  /// `From`
  String get platform_audit_filter_from {
    return Intl.message('From', name: 'platform_audit_filter_from', desc: '', args: []);
  }

  /// `To`
  String get platform_audit_filter_to {
    return Intl.message('To', name: 'platform_audit_filter_to', desc: '', args: []);
  }

  /// `Any day`
  String get platform_audit_filter_any_day {
    return Intl.message('Any day', name: 'platform_audit_filter_any_day', desc: '', args: []);
  }

  /// `Clear the date`
  String get platform_audit_filter_clear_date {
    return Intl.message('Clear the date', name: 'platform_audit_filter_clear_date', desc: '', args: []);
  }

  /// `Statement text`
  String get platform_audit_filter_search {
    return Intl.message('Statement text', name: 'platform_audit_filter_search', desc: '', args: []);
  }

  /// `Text in the statement, any case`
  String get platform_audit_filter_search_hint {
    return Intl.message(
      'Text in the statement, any case',
      name: 'platform_audit_filter_search_hint',
      desc: '',
      args: [],
    );
  }

  /// `Done`
  String get platform_audit_filter_done {
    return Intl.message('Done', name: 'platform_audit_filter_done', desc: '', args: []);
  }

  /// `Status: {value}`
  String platform_audit_chip_status(String value) {
    return Intl.message('Status: $value', name: 'platform_audit_chip_status', desc: '', args: [value]);
  }

  /// `Type: {value}`
  String platform_audit_chip_statement_type(String value) {
    return Intl.message('Type: $value', name: 'platform_audit_chip_statement_type', desc: '', args: [value]);
  }

  /// `Source: {value}`
  String platform_audit_chip_source(String value) {
    return Intl.message('Source: $value', name: 'platform_audit_chip_source', desc: '', args: [value]);
  }

  /// `From {date}`
  String platform_audit_chip_from(String date) {
    return Intl.message('From $date', name: 'platform_audit_chip_from', desc: '', args: [date]);
  }

  /// `To {date}`
  String platform_audit_chip_to(String date) {
    return Intl.message('To $date', name: 'platform_audit_chip_to', desc: '', args: [date]);
  }

  /// `Text: {text}`
  String platform_audit_chip_search(String text) {
    return Intl.message('Text: $text', name: 'platform_audit_chip_search', desc: '', args: [text]);
  }

  /// `User: {user}`
  String platform_audit_chip_user(String user) {
    return Intl.message('User: $user', name: 'platform_audit_chip_user', desc: '', args: [user]);
  }

  /// `Connection: {connection}`
  String platform_audit_chip_connection(String connection) {
    return Intl.message(
      'Connection: $connection',
      name: 'platform_audit_chip_connection',
      desc: '',
      args: [connection],
    );
  }

  /// `Remove this filter`
  String get platform_audit_chip_remove {
    return Intl.message('Remove this filter', name: 'platform_audit_chip_remove', desc: '', args: []);
  }

  /// `Not recorded`
  String get platform_audit_not_recorded {
    return Intl.message('Not recorded', name: 'platform_audit_not_recorded', desc: '', args: []);
  }

  /// `Event id`
  String get platform_audit_field_event_id {
    return Intl.message('Event id', name: 'platform_audit_field_event_id', desc: '', args: []);
  }

  /// `Started`
  String get platform_audit_field_started {
    return Intl.message('Started', name: 'platform_audit_field_started', desc: '', args: []);
  }

  /// `Finished`
  String get platform_audit_field_finished {
    return Intl.message('Finished', name: 'platform_audit_field_finished', desc: '', args: []);
  }

  /// `User`
  String get platform_audit_field_user {
    return Intl.message('User', name: 'platform_audit_field_user', desc: '', args: []);
  }

  /// `Keycloak id`
  String get platform_audit_field_subject {
    return Intl.message('Keycloak id', name: 'platform_audit_field_subject', desc: '', args: []);
  }

  /// `Session role`
  String get platform_audit_field_session_role {
    return Intl.message('Session role', name: 'platform_audit_field_session_role', desc: '', args: []);
  }

  /// `Connection`
  String get platform_audit_field_connection {
    return Intl.message('Connection', name: 'platform_audit_field_connection', desc: '', args: []);
  }

  /// `Connection id`
  String get platform_audit_field_connection_id {
    return Intl.message('Connection id', name: 'platform_audit_field_connection_id', desc: '', args: []);
  }

  /// `Engine`
  String get platform_audit_field_engine {
    return Intl.message('Engine', name: 'platform_audit_field_engine', desc: '', args: []);
  }

  /// `Access level`
  String get platform_audit_field_access_level {
    return Intl.message('Access level', name: 'platform_audit_field_access_level', desc: '', args: []);
  }

  /// `Source`
  String get platform_audit_field_source {
    return Intl.message('Source', name: 'platform_audit_field_source', desc: '', args: []);
  }

  /// `Statement type`
  String get platform_audit_field_statement_type {
    return Intl.message('Statement type', name: 'platform_audit_field_statement_type', desc: '', args: []);
  }

  /// `Explain`
  String get platform_audit_field_explain {
    return Intl.message('Explain', name: 'platform_audit_field_explain', desc: '', args: []);
  }

  /// `Statement capture`
  String get platform_audit_field_capture {
    return Intl.message('Statement capture', name: 'platform_audit_field_capture', desc: '', args: []);
  }

  /// `Statement`
  String get platform_audit_field_statement {
    return Intl.message('Statement', name: 'platform_audit_field_statement', desc: '', args: []);
  }

  /// `Rows`
  String get platform_audit_field_rows {
    return Intl.message('Rows', name: 'platform_audit_field_rows', desc: '', args: []);
  }

  /// `Duration`
  String get platform_audit_field_duration {
    return Intl.message('Duration', name: 'platform_audit_field_duration', desc: '', args: []);
  }

  /// `Status`
  String get platform_audit_field_status {
    return Intl.message('Status', name: 'platform_audit_field_status', desc: '', args: []);
  }

  /// `Error code`
  String get platform_audit_field_error_code {
    return Intl.message('Error code', name: 'platform_audit_field_error_code', desc: '', args: []);
  }

  /// `Error message`
  String get platform_audit_field_error_message {
    return Intl.message('Error message', name: 'platform_audit_field_error_message', desc: '', args: []);
  }

  /// `Transaction outcome`
  String get platform_audit_field_transaction {
    return Intl.message('Transaction outcome', name: 'platform_audit_field_transaction', desc: '', args: []);
  }

  /// `Full`
  String get platform_audit_capture_full {
    return Intl.message('Full', name: 'platform_audit_capture_full', desc: '', args: []);
  }

  /// `Redacted`
  String get platform_audit_capture_redacted {
    return Intl.message('Redacted', name: 'platform_audit_capture_redacted', desc: '', args: []);
  }

  /// `None`
  String get platform_audit_capture_none {
    return Intl.message('None', name: 'platform_audit_capture_none', desc: '', args: []);
  }

  /// `Truncated by Studio`
  String get platform_audit_statement_truncated {
    return Intl.message('Truncated by Studio', name: 'platform_audit_statement_truncated', desc: '', args: []);
  }

  /// `Redacted by the connection's capture setting`
  String get platform_audit_statement_redacted {
    return Intl.message(
      'Redacted by the connection\'s capture setting',
      name: 'platform_audit_statement_redacted',
      desc: '',
      args: [],
    );
  }

  /// `Not captured`
  String get platform_audit_statement_none {
    return Intl.message('Not captured', name: 'platform_audit_statement_none', desc: '', args: []);
  }

  /// `Only this user`
  String get platform_audit_only_this_user {
    return Intl.message('Only this user', name: 'platform_audit_only_this_user', desc: '', args: []);
  }

  /// `Only this connection`
  String get platform_audit_only_this_connection {
    return Intl.message('Only this connection', name: 'platform_audit_only_this_connection', desc: '', args: []);
  }

  /// `Skip`
  String get ob_skip {
    return Intl.message(
      'Skip',
      name: 'ob_skip',
      desc: 'Leaves the six onboarding screens for the sign-in page; the word the app\'s older onboarding uses.',
      args: [],
    );
  }

  /// `Next`
  String get ob_next {
    return Intl.message(
      'Next',
      name: 'ob_next',
      desc: 'Moves to the next onboarding screen; the word the app\'s older onboarding uses.',
      args: [],
    );
  }

  /// `Sign in`
  String get ob_done {
    return Intl.message(
      'Sign in',
      name: 'ob_done',
      desc: 'On the last onboarding screen, in place of Next: ends the introduction and opens the sign-in page.',
      args: [],
    );
  }

  /// `{current} / {total}`
  String ob_step(int current, int total) {
    return Intl.message(
      '$current / $total',
      name: 'ob_step',
      desc: 'The step counter in the corner of each onboarding screen, shown as 01 / 06; the widget pads each number to two digits.',
      args: [current, total],
    );
  }

  /// `Step {current} of {total}`
  String ob_step_semantics(int current, int total) {
    return Intl.message(
      'Step $current of $total',
      name: 'ob_step_semantics',
      desc: 'What a screen reader says for the step counter, which is drawn as padded digits.',
      args: [current, total],
    );
  }

  /// `your connections`
  String get ob1_cap {
    return Intl.message(
      'your connections',
      name: 'ob1_cap',
      desc: 'The caption over the first onboarding screen, which shows the connection list.',
      args: [],
    );
  }

  /// `The databases\nyou've been given.`
  String get ob1_title {
    return Intl.message(
      'The databases\nyou\'ve been given.',
      name: 'ob1_title',
      desc: 'The headline of the first onboarding screen. The line break is deliberate.',
      args: [],
    );
  }

  /// `been given`
  String get ob1_accent {
    return Intl.message(
      'been given',
      name: 'ob1_accent',
      desc: 'The run of ob1_title the screen paints in the accent colour; it must appear in ob1_title verbatim.',
      args: [],
    );
  }

  /// `PROD, STAGING, DEV — the badge says which one you are on. The read-only ones are marked.`
  String get ob1_body {
    return Intl.message(
      'PROD, STAGING, DEV — the badge says which one you are on. The read-only ones are marked.',
      name: 'ob1_body',
      desc: 'The body of the first onboarding screen.',
      args: [],
    );
  }

  /// `Until someone grants you one, the list reads: "{line}"`
  String ob1_empty(String line) {
    return Intl.message(
      'Until someone grants you one, the list reads: "$line"',
      name: 'ob1_empty',
      desc: 'Under the demo connection list: what the real list says when nothing has been granted. Pass connection_list_empty_governed as {line} rather than repeating it here.',
      args: [line],
    );
  }

  /// `{connection} · browse`
  String ob2_cap(String connection) {
    return Intl.message(
      '$connection · browse',
      name: 'ob2_cap',
      desc: 'The caption over the second onboarding screen, which browses a demo connection.',
      args: [connection],
    );
  }

  /// `Open it. Read it.\nSome columns are masked.`
  String get ob2_title {
    return Intl.message(
      'Open it. Read it.\nSome columns are masked.',
      name: 'ob2_title',
      desc: 'The headline of the second onboarding screen. The line break is deliberate.',
      args: [],
    );
  }

  /// `masked`
  String get ob2_accent {
    return Intl.message(
      'masked',
      name: 'ob2_accent',
      desc: 'The run of ob2_title the screen paints in the accent colour; it must appear in ob2_title verbatim.',
      args: [],
    );
  }

  /// `Schemas, tables, row counts. The rule is Studio's; the phone applies it.`
  String get ob2_body {
    return Intl.message(
      'Schemas, tables, row counts. The rule is Studio\'s; the phone applies it.',
      name: 'ob2_body',
      desc: 'The body of the second onboarding screen.',
      args: [],
    );
  }

  /// `masked by column name —\nthere is no switch here to turn it off`
  String get ob2_why {
    return Intl.message(
      'masked by column name —\nthere is no switch here to turn it off',
      name: 'ob2_why',
      desc:
          'The note under the demo result grid, once its e-mail column has been masked. The line break is deliberate.',
      args: [],
    );
  }

  /// `{count, plural, =1{1 table} other{{count} tables}}`
  String ob2_tables(int count) {
    return Intl.plural(
      count,
      one: '1 table',
      other: '$count tables',
      name: 'ob2_tables',
      desc: 'How many tables the demo schema row holds, beside the schema\'s name.',
      args: [count],
    );
  }

  /// `editor · {connection}`
  String ob3_cap(String connection) {
    return Intl.message(
      'editor · $connection',
      name: 'ob3_cap',
      desc: 'The caption over the third onboarding screen, which runs a statement on a demo connection.',
      args: [connection],
    );
  }

  /// `Run it.\nThen try a delete.`
  String get ob3_title {
    return Intl.message(
      'Run it.\nThen try a delete.',
      name: 'ob3_title',
      desc: 'The headline of the third onboarding screen. The line break is deliberate.',
      args: [],
    );
  }

  /// `try a delete`
  String get ob3_accent {
    return Intl.message(
      'try a delete',
      name: 'ob3_accent',
      desc: 'The run of ob3_title the screen paints in the accent colour; it must appear in ob3_title verbatim.',
      args: [],
    );
  }

  /// `Anything that may change data asks first. On a production connection you type its name.`
  String get ob3_body {
    return Intl.message(
      'Anything that may change data asks first. On a production connection you type its name.',
      name: 'ob3_body',
      desc: 'The body of the third onboarding screen.',
      args: [],
    );
  }

  /// `count`
  String get ob3_count {
    return Intl.message(
      'count',
      name: 'ob3_count',
      desc: 'The header of the demo result card, the column name the counting statement answers with.',
      args: [],
    );
  }

  /// `{rows} · {duration}`
  String ob3_meta(String rows, String duration) {
    return Intl.message(
      '$rows · $duration',
      name: 'ob3_meta',
      desc: 'Beside the demo Run button once the statement answered: its rows and how long it took. Pass sql_history_rows as {rows} and sql_history_duration as {duration} rather than repeating either here.',
      args: [rows, duration],
    );
  }

  /// `where the password was`
  String get ob4_cap {
    return Intl.message(
      'where the password was',
      name: 'ob4_cap',
      desc: 'The caption over the fourth onboarding screen, which shows where a database password lives.',
      args: [],
    );
  }

  /// `Studio holds it.\nYou never do.`
  String get ob4_title {
    return Intl.message(
      'Studio holds it.\nYou never do.',
      name: 'ob4_title',
      desc: 'The headline of the fourth onboarding screen. The line break is deliberate.',
      args: [],
    );
  }

  /// `Studio`
  String get ob4_accent {
    return Intl.message(
      'Studio',
      name: 'ob4_accent',
      desc: 'The run of ob4_title the screen paints in the accent colour; it must appear in ob4_title verbatim.',
      args: [],
    );
  }

  /// `No database password is on the phone — only a session that expires. With the app lock on, that session sits behind the lock too.`
  String get ob4_body {
    return Intl.message(
      'No database password is on the phone — only a session that expires. With the app lock on, that session sits behind the lock too.',
      name: 'ob4_body',
      desc: 'The body of the fourth onboarding screen.',
      args: [],
    );
  }

  /// `This app`
  String get ob4_app {
    return Intl.message(
      'This app',
      name: 'ob4_app',
      desc: 'The top node of the fourth onboarding screen\'s chain: this phone.',
      args: [],
    );
  }

  /// `LibreDB Studio`
  String get ob4_studio {
    return Intl.message(
      'LibreDB Studio',
      name: 'ob4_studio',
      desc: 'The middle node of the fourth onboarding screen\'s chain. A product name, the same in every language.',
      args: [],
    );
  }

  /// `the password stays here`
  String get ob4_vault {
    return Intl.message(
      'the password stays here',
      name: 'ob4_vault',
      desc: 'Under the Studio node of the fourth onboarding screen, beside the closing padlock.',
      args: [],
    );
  }

  /// `connects`
  String get ob4_connects {
    return Intl.message(
      'connects',
      name: 'ob4_connects',
      desc: 'The label on the wire from Studio down to the database on the fourth onboarding screen.',
      args: [],
    );
  }

  /// `rows come back to you — the password never does`
  String get ob4_back {
    return Intl.message(
      'rows come back to you — the password never does',
      name: 'ob4_back',
      desc: 'The closing note of the fourth onboarding screen, under an arrow pointing back up the chain.',
      args: [],
    );
  }

  /// `the ecosystem`
  String get ob5_cap {
    return Intl.message(
      'the ecosystem',
      name: 'ob5_cap',
      desc: 'The caption over the fifth onboarding screen, which draws Platform, the Studios and the databases.',
      args: [],
    );
  }

  /// `Studios connect\nto Platform.`
  String get ob5_title {
    return Intl.message(
      'Studios connect\nto Platform.',
      name: 'ob5_title',
      desc: 'The headline of the fifth onboarding screen. The line break is deliberate.',
      args: [],
    );
  }

  /// `to Platform`
  String get ob5_accent {
    return Intl.message(
      'to Platform',
      name: 'ob5_accent',
      desc: 'The run of ob5_title the screen paints in the accent colour; it must appear in ob5_title verbatim.',
      args: [],
    );
  }

  /// `Keycloak knows you once. Your phone talks to a Studio. The connections, the grants and the log live in the Platform above them — the administrator's side.`
  String get ob5_body {
    return Intl.message(
      'Keycloak knows you once. Your phone talks to a Studio. The connections, the grants and the log live in the Platform above them — the administrator\'s side.',
      name: 'ob5_body',
      desc: 'The body of the fifth onboarding screen.',
      args: [],
    );
  }

  /// `Keycloak`
  String get ob5_keycloak {
    return Intl.message(
      'Keycloak',
      name: 'ob5_keycloak',
      desc: 'The provider node at the top of the fifth onboarding screen. A product name, the same in every language.',
      args: [],
    );
  }

  /// `knows you once`
  String get ob5_keycloak_note {
    return Intl.message(
      'knows you once',
      name: 'ob5_keycloak_note',
      desc: 'Under the Keycloak node of the fifth onboarding screen.',
      args: [],
    );
  }

  /// `your phone`
  String get ob5_you {
    return Intl.message(
      'your phone',
      name: 'ob5_you',
      desc: 'The node for this device on the fifth onboarding screen.',
      args: [],
    );
  }

  /// `LibreDB Platform`
  String get ob5_hub {
    return Intl.message(
      'LibreDB Platform',
      name: 'ob5_hub',
      desc: 'The hub node of the fifth onboarding screen. A product name, the same in every language.',
      args: [],
    );
  }

  /// `Connections`
  String get ob5_role_connections {
    return Intl.message(
      'Connections',
      name: 'ob5_role_connections',
      desc: 'One of the three things the Platform hub holds, on a chip of the fifth onboarding screen. Render it as written: Dart\'s toUpperCase turns the Turkish i into I, not İ.',
      args: [],
    );
  }

  /// `Grants`
  String get ob5_role_grants {
    return Intl.message(
      'Grants',
      name: 'ob5_role_grants',
      desc: 'One of the three things the Platform hub holds, on a chip of the fifth onboarding screen. Render it as written: Dart\'s toUpperCase turns the Turkish i into I, not İ.',
      args: [],
    );
  }

  /// `Audit log`
  String get ob5_role_audit {
    return Intl.message(
      'Audit log',
      name: 'ob5_role_audit',
      desc: 'One of the three things the Platform hub holds, on a chip of the fifth onboarding screen. Render it as written: Dart\'s toUpperCase turns the Turkish i into I, not İ.',
      args: [],
    );
  }

  /// `same session, no second sign-in — the first switch takes an admin seat`
  String get ob5_mode_note {
    return Intl.message(
      'same session, no second sign-in — the first switch takes an admin seat',
      name: 'ob5_mode_note',
      desc: 'Under the Studio / Platform admin pills at the foot of the fifth onboarding screen.',
      args: [],
    );
  }

  /// `platform · access and record`
  String get ob6_cap {
    return Intl.message(
      'platform · access and record',
      name: 'ob6_cap',
      desc: 'The caption over the sixth onboarding screen, which shows a grant list and an audit log.',
      args: [],
    );
  }

  /// `Platform decides\nwho may reach what.`
  String get ob6_title {
    return Intl.message(
      'Platform decides\nwho may reach what.',
      name: 'ob6_title',
      desc: 'The headline of the sixth onboarding screen. The line break is deliberate.',
      args: [],
    );
  }

  /// `Platform`
  String get ob6_accent {
    return Intl.message(
      'Platform',
      name: 'ob6_accent',
      desc: 'The run of ob6_title the screen paints in the accent colour; it must appear in ob6_title verbatim.',
      args: [],
    );
  }

  /// `Platform grants access, ends it and sets when it expires. The statement you ran is in this log too.`
  String get ob6_body {
    return Intl.message(
      'Platform grants access, ends it and sets when it expires. The statement you ran is in this log too.',
      name: 'ob6_body',
      desc: 'The body of the sixth onboarding screen.',
      args: [],
    );
  }

  /// `you`
  String get ob6_you {
    return Intl.message(
      'you',
      name: 'ob6_you',
      desc: 'Names the reader\'s own row in the demo grant list and the demo audit log of the sixth onboarding screen.',
      args: [],
    );
  }

  /// `My requests`
  String get access_requests_title {
    return Intl.message('My requests', name: 'access_requests_title', desc: '', args: []);
  }

  /// `Request access`
  String get access_requests_new_title {
    return Intl.message('Request access', name: 'access_requests_new_title', desc: '', args: []);
  }

  /// `Access requests`
  String get access_requests_profile_tile {
    return Intl.message('Access requests', name: 'access_requests_profile_tile', desc: '', args: []);
  }

  /// `Request access`
  String get access_requests_empty_action {
    return Intl.message('Request access', name: 'access_requests_empty_action', desc: '', args: []);
  }

  /// `No requests yet`
  String get access_requests_empty_title {
    return Intl.message('No requests yet', name: 'access_requests_empty_title', desc: '', args: []);
  }

  /// `Ask for access to a connection and follow the answer here.`
  String get access_requests_empty_description {
    return Intl.message(
      'Ask for access to a connection and follow the answer here.',
      name: 'access_requests_empty_description',
      desc: '',
      args: [],
    );
  }

  /// `Your requests could not be loaded`
  String get access_requests_load_failed {
    return Intl.message('Your requests could not be loaded', name: 'access_requests_load_failed', desc: '', args: []);
  }

  /// `Pending`
  String get access_requests_status_pending {
    return Intl.message('Pending', name: 'access_requests_status_pending', desc: '', args: []);
  }

  /// `Approved`
  String get access_requests_status_approved {
    return Intl.message('Approved', name: 'access_requests_status_approved', desc: '', args: []);
  }

  /// `Refused`
  String get access_requests_status_refused {
    return Intl.message('Refused', name: 'access_requests_status_refused', desc: '', args: []);
  }

  /// `Withdrawn`
  String get access_requests_status_withdrawn {
    return Intl.message('Withdrawn', name: 'access_requests_status_withdrawn', desc: '', args: []);
  }

  /// `Read`
  String get access_requests_level_read {
    return Intl.message('Read', name: 'access_requests_level_read', desc: '', args: []);
  }

  /// `Write`
  String get access_requests_level_write {
    return Intl.message('Write', name: 'access_requests_level_write', desc: '', args: []);
  }

  /// `read`
  String get access_requests_level_read_in_sentence {
    return Intl.message('read', name: 'access_requests_level_read_in_sentence', desc: '', args: []);
  }

  /// `write`
  String get access_requests_level_write_in_sentence {
    return Intl.message('write', name: 'access_requests_level_write_in_sentence', desc: '', args: []);
  }

  /// `Sent {date}`
  String access_requests_sent_at(String date) {
    return Intl.message('Sent $date', name: 'access_requests_sent_at', desc: '', args: [date]);
  }

  /// `Administrator's reason: {reason}`
  String access_requests_refused_reason(String reason) {
    return Intl.message(
      'Administrator\'s reason: $reason',
      name: 'access_requests_refused_reason',
      desc: '',
      args: [reason],
    );
  }

  /// `The administrator gave no reason.`
  String get access_requests_refused_no_reason {
    return Intl.message(
      'The administrator gave no reason.',
      name: 'access_requests_refused_no_reason',
      desc: '',
      args: [],
    );
  }

  /// `The connection appears in your connection list after you refresh it. It can take a moment.`
  String get access_requests_approved_note {
    return Intl.message(
      'The connection appears in your connection list after you refresh it. It can take a moment.',
      name: 'access_requests_approved_note',
      desc: '',
      args: [],
    );
  }

  /// `Withdraw`
  String get access_requests_withdraw {
    return Intl.message('Withdraw', name: 'access_requests_withdraw', desc: '', args: []);
  }

  /// `Withdraw request`
  String get access_requests_withdraw_title {
    return Intl.message('Withdraw request', name: 'access_requests_withdraw_title', desc: '', args: []);
  }

  /// `Your request for {level} access to {connection} will be withdrawn. You can ask again later.`
  String access_requests_withdraw_message(String level, String connection) {
    return Intl.message(
      'Your request for $level access to $connection will be withdrawn. You can ask again later.',
      name: 'access_requests_withdraw_message',
      desc: '',
      args: [level, connection],
    );
  }

  /// `Request withdrawn.`
  String get access_requests_withdrawn_snackbar {
    return Intl.message('Request withdrawn.', name: 'access_requests_withdrawn_snackbar', desc: '', args: []);
  }

  /// `Request sent.`
  String get access_requests_sent_snackbar {
    return Intl.message('Request sent.', name: 'access_requests_sent_snackbar', desc: '', args: []);
  }

  /// `Connection`
  String get access_requests_form_connection {
    return Intl.message('Connection', name: 'access_requests_form_connection', desc: '', args: []);
  }

  /// `There is no connection you can ask for right now.`
  String get access_requests_form_no_connections {
    return Intl.message(
      'There is no connection you can ask for right now.',
      name: 'access_requests_form_no_connections',
      desc: '',
      args: [],
    );
  }

  /// `The connections could not be loaded`
  String get access_requests_form_load_failed {
    return Intl.message(
      'The connections could not be loaded',
      name: 'access_requests_form_load_failed',
      desc: '',
      args: [],
    );
  }

  /// `You already have a pending request`
  String get access_requests_form_connection_pending {
    return Intl.message(
      'You already have a pending request',
      name: 'access_requests_form_connection_pending',
      desc: '',
      args: [],
    );
  }

  /// `You already have access`
  String get access_requests_form_connection_granted {
    return Intl.message('You already have access', name: 'access_requests_form_connection_granted', desc: '', args: []);
  }

  /// `Access level`
  String get access_requests_form_level {
    return Intl.message('Access level', name: 'access_requests_form_level', desc: '', args: []);
  }

  /// `This connection has no write credential, so write access cannot be requested.`
  String get access_requests_form_level_write_unavailable {
    return Intl.message(
      'This connection has no write credential, so write access cannot be requested.',
      name: 'access_requests_form_level_write_unavailable',
      desc: '',
      args: [],
    );
  }

  /// `You already have read access to this connection.`
  String get access_requests_form_level_read_held {
    return Intl.message(
      'You already have read access to this connection.',
      name: 'access_requests_form_level_read_held',
      desc: '',
      args: [],
    );
  }

  /// `Reason`
  String get access_requests_form_reason {
    return Intl.message('Reason', name: 'access_requests_form_reason', desc: '', args: []);
  }

  /// `Why do you need this access?`
  String get access_requests_form_reason_hint {
    return Intl.message('Why do you need this access?', name: 'access_requests_form_reason_hint', desc: '', args: []);
  }

  /// `Send request`
  String get access_requests_form_send {
    return Intl.message('Send request', name: 'access_requests_form_send', desc: '', args: []);
  }

  /// `Choose a connection.`
  String get access_requests_form_connection_required {
    return Intl.message('Choose a connection.', name: 'access_requests_form_connection_required', desc: '', args: []);
  }

  /// `Choose an access level.`
  String get access_requests_form_level_required {
    return Intl.message('Choose an access level.', name: 'access_requests_form_level_required', desc: '', args: []);
  }

  /// `Write a reason of 1 to 500 characters.`
  String get access_requests_form_reason_invalid {
    return Intl.message(
      'Write a reason of 1 to 500 characters.',
      name: 'access_requests_form_reason_invalid',
      desc: '',
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
