import 'package:flutter/material.dart';

const Key loginButtonSsoKey = Key("loginButtonSsoKey");
const Key loginButtonPlatformKey = Key("loginButtonPlatformKey");
const Key loginUnreachableRetryStudioKey = Key("loginUnreachableRetryStudioKey");
const Key loginUnreachableRetryPlatformKey = Key("loginUnreachableRetryPlatformKey");

// the progress over the shell while a sign-out runs
const Key signOutProgressIndicatorKey = Key("signOutProgressIndicatorKey");

// the profile sheet of the shell
const Key profileButtonKey = Key("profileButtonKey");
const Key profileSettingsKey = Key("profileSettingsKey");
const Key profileSignOutKey = Key("profileSignOutKey");
const Key profileIdentityRetryKey = Key("profileIdentityRetryKey");

// the page the shell shows when Studio refuses the signed-in account
const Key accountRefusalRetryKey = Key("accountRefusalRetryKey");
const Key accountRefusalSignOutKey = Key("accountRefusalSignOutKey");

// settings screen
const Key settingsChangeLanguageButtonKey = Key("settingsChangeLanguageButtonKey");
// Logout is intentionally not exposed from settings — it lives in the
// profile sheet of the shell (see SettingsScreen for the rationale).
const Key settingsRemoveMyDataKey = Key("settingsRemoveMyDataKey");
const Key removeMyDataConfirmKey = Key("removeMyDataConfirmKey");
const Key removeMyDataRetryKey = Key("removeMyDataRetryKey");
const Key removeMyDataProgressKey = Key("removeMyDataProgressKey");

// community section
const Key communityStarKey = Key("communityStarKey");
const Key communityIssueKey = Key("communityIssueKey");
const Key communityContributeKey = Key("communityContributeKey");
const Key communityTranslateKey = Key("communityTranslateKey");
const Key communitySponsorKey = Key("communitySponsorKey");
const Key communityDocsKey = Key("communityDocsKey");
const Key settingsWebsiteButtonKey = Key("settingsWebsiteButtonKey");
const Key settingsLicensesButtonKey = Key("settingsLicensesButtonKey");

// App lock: the lock screen over the app and its section of the settings.
const Key appLockScreenKey = Key("appLockScreenKey");
const Key appLockUnlockKey = Key("appLockUnlockKey");
const Key appLockSignOutKey = Key("appLockSignOutKey");
const Key appLockSwitchKey = Key("appLockSwitchKey");
const Key appLockTimeoutKey = Key("appLockTimeoutKey");
const Key appLockRestoreKey = Key("appLockRestoreKey");
