import 'package:flutter/material.dart';

const Key loginButtonSsoKey = Key("loginButtonSsoKey");

// the progress over the shell while a sign-out runs
const Key signOutProgressIndicatorKey = Key("signOutProgressIndicatorKey");

// the profile sheet of the shell
const Key profileButtonKey = Key("profileButtonKey");
const Key profileSettingsKey = Key("profileSettingsKey");
const Key profileSignOutKey = Key("profileSignOutKey");
const Key profileIdentityRetryKey = Key("profileIdentityRetryKey");

// settings screen
const Key settingsChangeLanguageButtonKey = Key("settingsChangeLanguageButtonKey");
// Logout is intentionally not exposed from settings — it lives in the
// profile sheet of the shell (see SettingsScreen for the rationale).

// community section
const Key communityStarKey = Key("communityStarKey");
const Key communityIssueKey = Key("communityIssueKey");
const Key communityContributeKey = Key("communityContributeKey");
const Key communityTranslateKey = Key("communityTranslateKey");
const Key communitySponsorKey = Key("communitySponsorKey");
const Key communityDocsKey = Key("communityDocsKey");
const Key settingsWebsiteButtonKey = Key("settingsWebsiteButtonKey");
const Key settingsLicensesButtonKey = Key("settingsLicensesButtonKey");
