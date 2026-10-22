import 'package:flutter/material.dart';

const Key loginTextFieldUsernameKey = Key("loginTextFieldUsernameKey");
const Key loginTextFieldPasswordKey = Key("loginTextFieldPasswordKey");
const Key loginButtonSubmitKey = Key("loginButtonSubmitKey");
const Key loginButtonForgotPasswordKey = Key("loginButtonForgotPasswordKey");
const Key loginButtonRegisterKey = Key("loginButtonRegisterKey");
const Key loginButtonPasswordVisibilityKey = Key("loginButtonPasswordVisibilityKey");
const Key loginButtonSsoKey = Key("loginButtonSsoKey");
const Key forgotPasswordButtonSubmitKey = Key("forgotPasswordButtonSubmit");
const Key forgotPasswordTextFieldEmailKey = Key("forgotPasswordTextFieldEmail");

// the progress over the shell while a sign-out runs
const Key signOutProgressIndicatorKey = Key("signOutProgressIndicatorKey");

// settings screen
const Key settingsChangePasswordButtonKey = Key("settingsChangePasswordButtonKey");
const Key settingsChangeLanguageButtonKey = Key("settingsChangeLanguageButtonKey");
// Logout is intentionally not exposed from settings — it lives in the
// top bar of the shell (see SettingsScreen for the rationale).

// change password screen
const Key changePasswordButtonSubmitKey = Key("changePasswordButtonSubmitKey");
const Key changePasswordTextFieldCurrentPasswordKey = Key("changePasswordTextFieldCurrentPasswordKey");
const Key changePasswordTextFieldNewPasswordKey = Key("changePasswordTextFieldNewPasswordKey");

// community section
const Key communityStarKey = Key("communityStarKey");
const Key communityIssueKey = Key("communityIssueKey");
const Key communityContributeKey = Key("communityContributeKey");
const Key communityTranslateKey = Key("communityTranslateKey");
const Key communitySponsorKey = Key("communitySponsorKey");
const Key communityDocsKey = Key("communityDocsKey");
const Key settingsWebsiteButtonKey = Key("settingsWebsiteButtonKey");
const Key settingsLicensesButtonKey = Key("settingsLicensesButtonKey");
