/// Template configuration for customizing this project.
///
/// Search for keywords starting with `__` (e.g. `__APP_NAME__`) across the
/// entire project and replace them with your own values.
/// See docs/template.md → "Customizing for Your Project" for the full keyword list.
class TemplateConfig {
  // App identity
  static const String appName = '__APP_NAME__';

  // API, given at build time with `--dart-define=PROD_API_URL=https://studio.example.com/api`, or by replacing the
  // placeholder here.
  static const String prodApiUrl = String.fromEnvironment('PROD_API_URL', defaultValue: '__PROD_API_URL__');

  // Links the app shows, given at build time, for example with
  // `--dart-define=GITHUB_REPO_URL=https://github.com/acme/dashboard`, or by replacing the placeholder here.
  // The app leaves out a link that is not given (see [isUnfilled]).
  static const String githubRepo = String.fromEnvironment('GITHUB_REPO_URL', defaultValue: '__GITHUB_REPO_URL__');
  static const String docsUrl = String.fromEnvironment('DOCS_URL', defaultValue: '__DOCS_URL__');
  static const String sponsorUrl = String.fromEnvironment('SPONSOR_URL', defaultValue: '__SPONSOR_URL__');

  /// Whether [value] has not been filled in: it is empty, or still a placeholder such as `__KEYWORD__`.
  static bool isUnfilled(String value) => value.isEmpty || _placeholder.hasMatch(value);

  /// `__`, a key of upper-case letters, digits and `_` that starts with a letter, and `__`.
  static final _placeholder = RegExp(r'^__[A-Z][A-Z0-9_]*__$');
}
