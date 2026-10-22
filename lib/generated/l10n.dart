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

  /// `First Name`
  String get first_name {
    return Intl.message('First Name', name: 'first_name', desc: '', args: []);
  }

  /// `Last Name`
  String get last_name {
    return Intl.message('Last Name', name: 'last_name', desc: '', args: []);
  }

  /// `Email`
  String get email {
    return Intl.message('Email', name: 'email', desc: '', args: []);
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

  /// `Field must be at least 2 characters long`
  String get min_length_2 {
    return Intl.message('Field must be at least 2 characters long', name: 'min_length_2', desc: '', args: []);
  }

  /// `Field must be at least 4 characters long`
  String get min_length_4 {
    return Intl.message('Field must be at least 4 characters long', name: 'min_length_4', desc: '', args: []);
  }

  /// `Field cannot be more than 20 characters long`
  String get max_length_20 {
    return Intl.message('Field cannot be more than 20 characters long', name: 'max_length_20', desc: '', args: []);
  }

  /// `Field cannot be more than 100 characters long`
  String get max_length_100 {
    return Intl.message('Field cannot be more than 100 characters long', name: 'max_length_100', desc: '', args: []);
  }

  /// `List`
  String get list {
    return Intl.message('List', name: 'list', desc: '', args: []);
  }

  /// `Email must be a valid email address`
  String get email_pattern {
    return Intl.message('Email must be a valid email address', name: 'email_pattern', desc: '', args: []);
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

  /// `Change Password`
  String get change_password {
    return Intl.message('Change Password', name: 'change_password', desc: '', args: []);
  }

  /// `Ensure your account is using a long, random password to stay secure.`
  String get change_password_description {
    return Intl.message(
      'Ensure your account is using a long, random password to stay secure.',
      name: 'change_password_description',
      desc: '',
      args: [],
    );
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

  /// `No changes made`
  String get no_changes_made {
    return Intl.message('No changes made', name: 'no_changes_made', desc: '', args: []);
  }

  /// `No Data`
  String get no_data {
    return Intl.message('No Data', name: 'no_data', desc: '', args: []);
  }

  /// `Username`
  String get login_user_name {
    return Intl.message('Username', name: 'login_user_name', desc: '', args: []);
  }

  /// `Password`
  String get login_password {
    return Intl.message('Password', name: 'login_password', desc: '', args: []);
  }

  /// `Current Password`
  String get current_password {
    return Intl.message('Current Password', name: 'current_password', desc: '', args: []);
  }

  /// `New Password`
  String get new_password {
    return Intl.message('New Password', name: 'new_password', desc: '', args: []);
  }

  /// `Forgot Password`
  String get password_forgot {
    return Intl.message('Forgot Password', name: 'password_forgot', desc: '', args: []);
  }

  /// `Register`
  String get register {
    return Intl.message('Register', name: 'register', desc: '', args: []);
  }

  /// `Password cannot be more than {max} characters long`
  String password_max_length(int max) {
    return Intl.message(
      'Password cannot be more than $max characters long',
      name: 'password_max_length',
      desc: '',
      args: [max],
    );
  }

  /// `Password must be at least {min} characters long`
  String password_min_length(int min) {
    return Intl.message(
      'Password must be at least $min characters long',
      name: 'password_min_length',
      desc: '',
      args: [min],
    );
  }

  /// `Login`
  String get login_button {
    return Intl.message('Login', name: 'login_button', desc: '', args: []);
  }

  /// `Loading...`
  String get loading {
    return Intl.message('Loading...', name: 'loading', desc: '', args: []);
  }

  /// `Send Email`
  String get email_send {
    return Intl.message('Send Email', name: 'email_send', desc: '', args: []);
  }

  /// `Login with Email`
  String get login_with_email {
    return Intl.message('Login with Email', name: 'login_with_email', desc: '', args: []);
  }

  /// `Send OTP Code`
  String get send_otp_code {
    return Intl.message('Send OTP Code', name: 'send_otp_code', desc: '', args: []);
  }

  /// `Invalid email address`
  String get invalid_email {
    return Intl.message('Invalid email address', name: 'invalid_email', desc: '', args: []);
  }

  /// `Resend OTP Code`
  String get resend_otp_code {
    return Intl.message('Resend OTP Code', name: 'resend_otp_code', desc: '', args: []);
  }

  /// `Verify OTP Code`
  String get verify_otp_code {
    return Intl.message('Verify OTP Code', name: 'verify_otp_code', desc: '', args: []);
  }

  /// `Only numbers are allowed`
  String get only_numbers {
    return Intl.message('Only numbers are allowed', name: 'only_numbers', desc: '', args: []);
  }

  /// `OTP must be 6 characters long`
  String get otp_length {
    return Intl.message('OTP must be 6 characters long', name: 'otp_length', desc: '', args: []);
  }

  /// `OTP Code`
  String get otp_code {
    return Intl.message('OTP Code', name: 'otp_code', desc: '', args: []);
  }

  /// `Theme`
  String get theme {
    return Intl.message('Theme', name: 'theme', desc: '', args: []);
  }

  /// `Language`
  String get language {
    return Intl.message('Language', name: 'language', desc: '', args: []);
  }

  /// `Dashboard`
  String get dashboard {
    return Intl.message('Dashboard', name: 'dashboard', desc: '', args: []);
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

  /// `Login failed`
  String get error_auth_login_failed {
    return Intl.message('Login failed', name: 'error_auth_login_failed', desc: '', args: []);
  }

  /// `Could not send the OTP code`
  String get error_auth_send_otp_failed {
    return Intl.message('Could not send the OTP code', name: 'error_auth_send_otp_failed', desc: '', args: []);
  }

  /// `OTP validation failed`
  String get error_auth_otp_validation {
    return Intl.message('OTP validation failed', name: 'error_auth_otp_validation', desc: '', args: []);
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

  /// `Both current and new password are required`
  String get error_account_password_required {
    return Intl.message(
      'Both current and new password are required',
      name: 'error_account_password_required',
      desc: '',
      args: [],
    );
  }

  /// `New password must be different from current password`
  String get error_account_passwords_same {
    return Intl.message(
      'New password must be different from current password',
      name: 'error_account_passwords_same',
      desc: '',
      args: [],
    );
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

  /// `Access denied`
  String get forbidden_title {
    return Intl.message('Access denied', name: 'forbidden_title', desc: '', args: []);
  }

  /// `You do not have permission to view this page.`
  String get forbidden_message {
    return Intl.message('You do not have permission to view this page.', name: 'forbidden_message', desc: '', args: []);
  }

  /// `Back to home`
  String get forbidden_back_home {
    return Intl.message('Back to home', name: 'forbidden_back_home', desc: '', args: []);
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

  /// `Enter your credentials to access your account`
  String get login_welcome_subtitle {
    return Intl.message(
      'Enter your credentials to access your account',
      name: 'login_welcome_subtitle',
      desc: '',
      args: [],
    );
  }

  /// `or`
  String get login_or {
    return Intl.message('or', name: 'login_or', desc: '', args: []);
  }

  /// `Don't have an account? `
  String get login_no_account {
    return Intl.message('Don\'t have an account? ', name: 'login_no_account', desc: '', args: []);
  }

  /// `Switch to light mode`
  String get login_switch_to_light_mode {
    return Intl.message('Switch to light mode', name: 'login_switch_to_light_mode', desc: '', args: []);
  }

  /// `Switch to dark mode`
  String get login_switch_to_dark_mode {
    return Intl.message('Switch to dark mode', name: 'login_switch_to_dark_mode', desc: '', args: []);
  }

  /// `Enter your email to receive OTP code`
  String get login_otp_email_instructions {
    return Intl.message(
      'Enter your email to receive OTP code',
      name: 'login_otp_email_instructions',
      desc: '',
      args: [],
    );
  }

  /// `OTP sent to {email}`
  String otp_sent_to_email(String email) {
    return Intl.message('OTP sent to $email', name: 'otp_sent_to_email', desc: '', args: [email]);
  }

  /// `Source Available`
  String get community_source_available {
    return Intl.message('Source Available', name: 'community_source_available', desc: '', args: []);
  }

  /// `Create your account`
  String get register_subtitle {
    return Intl.message('Create your account', name: 'register_subtitle', desc: '', args: []);
  }

  /// `Enter your email address and we'll send you a link to reset your password.`
  String get forgot_password_description {
    return Intl.message(
      'Enter your email address and we\'ll send you a link to reset your password.',
      name: 'forgot_password_description',
      desc: '',
      args: [],
    );
  }

  /// `Manage your account preferences`
  String get settings_subtitle {
    return Intl.message('Manage your account preferences', name: 'settings_subtitle', desc: '', args: []);
  }

  /// `Update your password securely`
  String get settings_change_password_subtitle {
    return Intl.message('Update your password securely', name: 'settings_change_password_subtitle', desc: '', args: []);
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

  /// `Show password`
  String get password_show {
    return Intl.message('Show password', name: 'password_show', desc: '', args: []);
  }

  /// `Hide password`
  String get password_hide {
    return Intl.message('Hide password', name: 'password_hide', desc: '', args: []);
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

  /// `Your account has no role that allows access to this app. Ask your administrator.`
  String get error_auth_oidc_no_role {
    return Intl.message(
      'Your account has no role that allows access to this app. Ask your administrator.',
      name: 'error_auth_oidc_no_role',
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

  /// `Databases Studio offers you`
  String get connection_list_subtitle {
    return Intl.message('Databases Studio offers you', name: 'connection_list_subtitle', desc: '', args: []);
  }

  /// `Studio offers you no connection yet`
  String get connection_list_empty {
    return Intl.message('Studio offers you no connection yet', name: 'connection_list_empty', desc: '', args: []);
  }

  /// `Could not load the connections`
  String get connection_list_load_failed {
    return Intl.message('Could not load the connections', name: 'connection_list_load_failed', desc: '', args: []);
  }

  /// `Name`
  String get connection_name {
    return Intl.message('Name', name: 'connection_name', desc: '', args: []);
  }

  /// `Engine`
  String get connection_type {
    return Intl.message('Engine', name: 'connection_type', desc: '', args: []);
  }

  /// `Environment`
  String get connection_environment {
    return Intl.message('Environment', name: 'connection_environment', desc: '', args: []);
  }

  /// `Target`
  String get connection_target {
    return Intl.message('Target', name: 'connection_target', desc: '', args: []);
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
