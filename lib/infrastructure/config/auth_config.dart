/// The values given at build time that decide how the user signs in through the OpenID Connect provider.
///
/// Each value defaults to its `--dart-define` (`OIDC_ISSUER`, `OIDC_CLIENT_ID` and so on), which are compile-time
/// constants, so production code uses `const AuthDefines()` and a test passes its own values. An unset define reads as
/// the empty string. [AuthMode.fromDefines] reads them.
final class AuthDefines {
  const AuthDefines({
    this._oidcIssuer = const String.fromEnvironment('OIDC_ISSUER'),
    this._oidcClientId = const String.fromEnvironment('OIDC_CLIENT_ID'),
    this._oidcScope = const String.fromEnvironment('OIDC_SCOPE'),
    this._oidcAudience = const String.fromEnvironment('OIDC_AUDIENCE'),
    this._oidcRoleClaim = const String.fromEnvironment('OIDC_ROLE_CLAIM'),
    this._oidcAdminRoles = const String.fromEnvironment('OIDC_ADMIN_ROLES'),
    this._oidcUserRoles = const String.fromEnvironment('OIDC_USER_ROLES'),
    this._oidcPrompt = const String.fromEnvironment('OIDC_PROMPT'),
    this._oidcAutoRedirect = const String.fromEnvironment('OIDC_AUTO_REDIRECT'),
    this._oidcLogoutHint = const String.fromEnvironment('OIDC_LOGOUT_HINT'),
    this._oidcRedirectScheme = const String.fromEnvironment('OIDC_REDIRECT_SCHEME'),
  });

  final String _oidcIssuer;
  final String _oidcClientId;
  final String _oidcScope;
  final String _oidcAudience;
  final String _oidcRoleClaim;
  final String _oidcAdminRoles;
  final String _oidcUserRoles;
  final String _oidcPrompt;
  final String _oidcAutoRedirect;
  final String _oidcLogoutHint;
  final String _oidcRedirectScheme;
}

/// How the user signs in: always through the OpenID Connect provider (Keycloak), whose access token is the bearer
/// LibreDB Studio accepts. Read at bootstrap and injected through `AppDependencies`.
sealed class AuthMode {
  const AuthMode();

  /// Reads the `OIDC_*` values of [defines]: [OidcAuthMode], or [OidcMisconfiguredAuthMode] when the settings break a
  /// rule, a build without them included. There is no other way to sign in, so a misconfigured build fails closed.
  static AuthMode fromDefines(AuthDefines defines) {
    try {
      return OidcAuthMode(OidcSettings.parse(defines));
    } on OidcConfigException catch (error) {
      return OidcMisconfiguredAuthMode(error.reason);
    }
  }
}

/// The sign-in through the OpenID Connect provider that [settings] describe.
final class OidcAuthMode extends AuthMode {
  const OidcAuthMode(this.settings);

  final OidcSettings settings;
}

/// A build whose OpenID Connect settings break a rule. The app still starts, and the login page says that single
/// sign-on is not configured correctly; [reason] goes to the log.
final class OidcMisconfiguredAuthMode extends AuthMode {
  const OidcMisconfiguredAuthMode(this.reason);

  /// The variable and the rule it breaks, written for an administrator.
  final String reason;
}

/// The `prompt` the authorization request sends, read from `OIDC_PROMPT`.
enum OidcPrompt {
  login('login'),
  consent('consent'),
  selectAccount('select_account'),

  /// Sends no `prompt`.
  omit(null);

  const OidcPrompt(this.parameter);

  /// The value of the `prompt` parameter, or null when none is sent.
  final String? parameter;
}

/// The OpenID Connect settings of the build. The app is a public client, so there is no client secret.
final class OidcSettings {
  const OidcSettings({
    required this.issuer,
    required this.clientId,
    this.scopes = defaultScopes,
    this.audience,
    this.roleClaim,
    this.adminRoles = const ['admin'],
    this.userRoles = const [],
    this.prompt = OidcPrompt.login,
    this.autoRedirect = false,
    this.logoutHint = true,
    this.redirectScheme = defaultRedirectScheme,
  });

  /// The custom URI scheme of the redirect. It must equal the Android manifest placeholder.
  static const String defaultRedirectScheme = 'org.libredb.mobile';

  static const List<String> defaultScopes = ['openid', 'profile', 'email'];

  static const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

  /// An RFC 3986 scheme in lower case: a letter, then letters, digits, `+`, `-` or `.`. Upper case is refused because
  /// `Uri` lower-cases the scheme of the redirect URI, while Android matches the intent-filter scheme case-sensitively.
  static final _scheme = RegExp(r'^[a-z][a-z0-9+.\-]*$');

  /// Reads the `OIDC_*` values of [defines].
  ///
  /// Throws [OidcConfigException] naming the variable and the first rule it breaks. The settings hold no secret, so
  /// the reason may quote a value.
  static OidcSettings parse(AuthDefines defines) {
    final issuer = _issuer(defines._oidcIssuer.trim());
    final clientId = defines._oidcClientId.trim();
    if (clientId.isEmpty) throw const OidcConfigException('OIDC_CLIENT_ID is required');
    final scopes = defines._oidcScope.trim().split(RegExp(r'\s+')).where((scope) => scope.isNotEmpty).toList();
    if (scopes.isNotEmpty && !scopes.contains('openid')) {
      throw OidcConfigException('OIDC_SCOPE must contain openid, but it is "${defines._oidcScope.trim()}"');
    }
    final roleClaim = _optional(defines._oidcRoleClaim);
    final adminRoles = _list(defines._oidcAdminRoles);
    final userRoles = _list(defines._oidcUserRoles);
    if (userRoles.isNotEmpty && roleClaim == null) {
      throw const OidcConfigException('OIDC_USER_ROLES needs OIDC_ROLE_CLAIM, which is unset');
    }
    return OidcSettings(
      issuer: issuer,
      clientId: clientId,
      scopes: scopes.isEmpty ? defaultScopes : scopes,
      audience: _optional(defines._oidcAudience),
      roleClaim: roleClaim,
      adminRoles: adminRoles.isEmpty ? const ['admin'] : adminRoles,
      userRoles: userRoles,
      prompt: _prompt(defines._oidcPrompt),
      autoRedirect: _flag('OIDC_AUTO_REDIRECT', defines._oidcAutoRedirect, whenUnset: false),
      logoutHint: _flag('OIDC_LOGOUT_HINT', defines._oidcLogoutHint, whenUnset: true),
      redirectScheme: _redirectScheme(defines._oidcRedirectScheme.trim()),
    );
  }

  static Uri _issuer(String value) {
    if (value.isEmpty) throw const OidcConfigException('OIDC_ISSUER is required');
    // Uri.parse lower-cases the scheme and the host, and gives the host of `[::1]` without its brackets.
    final uri = Uri.tryParse(value);
    final valid =
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || (uri.scheme == 'http' && _loopbackHosts.contains(uri.host)));
    if (!valid) {
      throw OidcConfigException(
        'OIDC_ISSUER must be an absolute https URL, or http on localhost, 127.0.0.1 or [::1], but it is "$value"',
      );
    }
    // OpenID Connect Discovery 1.0 section 2 forbids a query and a fragment in the issuer.
    if (uri.hasQuery || uri.hasFragment) {
      throw OidcConfigException('OIDC_ISSUER must have no query and no fragment, but it is "$value"');
    }
    return uri;
  }

  static OidcPrompt _prompt(String value) => switch (value.trim().toLowerCase()) {
    '' || 'login' => OidcPrompt.login,
    'consent' => OidcPrompt.consent,
    'select_account' => OidcPrompt.selectAccount,
    'omit' => OidcPrompt.omit,
    _ => throw OidcConfigException(
      'OIDC_PROMPT must be login, consent, select_account or omit, but it is "${value.trim()}"',
    ),
  };

  static bool _flag(String name, String value, {required bool whenUnset}) => switch (value.trim().toLowerCase()) {
    '' => whenUnset,
    'true' || '1' || 'on' || 'yes' => true,
    'false' || '0' || 'off' || 'no' => false,
    _ => throw OidcConfigException('$name must be true, 1, on, yes, false, 0, off or no, but it is "${value.trim()}"'),
  };

  static String _redirectScheme(String value) {
    if (value.isEmpty) return defaultRedirectScheme;
    if (!_scheme.hasMatch(value)) {
      throw OidcConfigException(
        'OIDC_REDIRECT_SCHEME must start with a lower-case letter followed by lower-case letters, digits, +, - or ., '
        'but it is "$value"',
      );
    }
    return value;
  }

  /// The trimmed [value], or null when it is empty.
  static String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The trimmed non-empty items of the comma list [value].
  static List<String> _list(String value) =>
      [for (final item in value.split(',')) item.trim()].where((item) => item.isNotEmpty).toList();

  /// The issuer, with discovery at `/.well-known/openid-configuration` under it.
  final Uri issuer;

  /// The public client id.
  final String clientId;
  final List<String> scopes;

  /// Sent as `audience` on the authorization request (Auth0), or null to send none.
  final String? audience;

  /// The dot path to the role claim in the ID token, such as `realm_access.roles`.
  final String? roleClaim;
  final List<String> adminRoles;

  /// When not empty, an account with neither an admin nor a user role is refused.
  final List<String> userRoles;
  final OidcPrompt prompt;

  /// Whether the login page sends the user to the provider without waiting for a tap.
  final bool autoRedirect;

  /// Whether the provider logout sends the `id_token_hint`.
  final bool logoutHint;

  /// The custom URI scheme of the redirect.
  final String redirectScheme;

  /// The redirect URI of a sign-in and of a provider logout, `<redirectScheme>:/oauth2redirect`, which the provider
  /// must list for the client.
  Uri get redirectUri => Uri(scheme: redirectScheme, path: redirectPath);

  /// The path of [redirectUri], which the router must never show as a location.
  static const redirectPath = '/oauth2redirect';
}

/// Thrown by [OidcSettings.parse] for settings that break a rule.
final class OidcConfigException implements Exception {
  const OidcConfigException(this.reason);

  /// The variable and the rule it breaks, written for an administrator.
  final String reason;

  @override
  String toString() => 'OidcConfigException: $reason';
}
