import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/security/safe_redirect.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:go_router/go_router.dart';

import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/utils/app_constants.dart';

import '../../application/login_bloc.dart';
import '../../domain/services/sso_auto_redirect_gate.dart';
import '../../../../generated/l10n.dart';
import '../widgets/community_section_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onToggleTheme, this.startupSignInError});

  /// Wired by the router; null = non-interactive badge (features cannot import app/theme).
  final VoidCallback? onToggleTheme;

  /// Why single sign-on cannot run, as the startup step found, or null. Passed in by the router, which reads the
  /// session (features cannot import app/session). The single sign-on page shows it until the first tap.
  final AppErrorCode? startupSignInError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(debugLabel: '__loginScaffoldKey__');
  late AnimationController _animController;

  /// Whether the user has tapped a sign-in button on this visit of the page, which hides
  /// [LoginScreen.startupSignInError].
  bool _ssoTapped = false;

  /// The entries the page offers in an [OidcAuthMode], in their order: Studio alone, or Studio and Platform in a build
  /// with a Platform target.
  List<SessionTarget> get _entries => switch (context.read<AppConfig>().platform) {
    PlatformConfigured() => const [SessionTarget.studio, SessionTarget.platform],
    PlatformNotConfigured() => const [SessionTarget.studio],
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirectAutomatically());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget body = BlocListener<LoginBloc, LoginState>(
      listener: _onLoginStateChange,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            return isDesktop ? _desktopLayout(context, isDark) : _mobileLayout(context, isDark);
          },
        ),
      ),
    );
    return Scaffold(
      key: _scaffoldKey,
      body: switch (context.read<AuthMode>()) {
        // A sign-in that ends without a session closes the gate, so the page never sends the user back on its own.
        OidcAuthMode(:final settings) when settings.autoRedirect => BlocListener<LoginBloc, LoginState>(
          listenWhen: (previous, current) =>
              (previous is LoginLoadingState && current is LoginInitialState) || current is LoginErrorState,
          listener: (context, _) => context.read<SsoAutoRedirectGate>().close(),
          child: body,
        ),
        OidcAuthMode() || OidcMisconfiguredAuthMode() => body,
      },
    );
  }

  /// Sends the user to the identity provider without a tap, at most once per run: only in an [OidcAuthMode] with
  /// `autoRedirect` on and a single entry, while [SsoAutoRedirectGate] is open and no error shows on the page. The gate
  /// closes first. With two entries the user has to choose one, so the page never launches the provider and leaves
  /// the gate as it is.
  void _redirectAutomatically() {
    if (!mounted) return;
    final mode = context.read<AuthMode>();
    if (mode is! OidcAuthMode || !mode.settings.autoRedirect) return;
    if (_entries case [final target]) {
      final gate = context.read<SsoAutoRedirectGate>();
      if (!gate.isOpen || _ssoErrorCode(mode, context.read<LoginBloc>().state) != null) return;
      gate.close();
      _requestSso(context, target);
    }
  }

  Widget _desktopLayout(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(flex: 55, child: _brandPanel(context, isDark)),
        Expanded(flex: 45, child: _formPanel(context, isDark)),
      ],
    );
  }

  Widget _mobileLayout(BuildContext context, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(color: cs.surface),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeTransition(
                opacity: _animController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _brandIcon(isDark),
                    const SizedBox(height: 32),
                    _formHeading(context),
                    const SizedBox(height: 32),
                    _formBody(context, isDark, showCommunity: true),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 12, right: 12, child: _themeBadge(isDark)),
      ],
    );
  }

  Widget _brandPanel(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF020617), const Color(0xFF0C1222), const Color(0xFF020617)]
              : [const Color(0xFF0f172a), const Color(0xFF1B2B4B), const Color(0xFF0f172a)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -120, left: -80, child: _gradientOrb(420, const Color(0xFF6366F1), isDark ? 0.25 : 0.3)),
          Positioned(bottom: -180, right: -120, child: _gradientOrb(480, const Color(0xFF8B5CF6), isDark ? 0.2 : 0.25)),
          Positioned(top: 180, right: -60, child: _gradientOrb(280, const Color(0xFF06B6D4), isDark ? 0.15 : 0.18)),
          Positioned(bottom: 100, left: -40, child: _gradientOrb(200, const Color(0xFF3B82F6), isDark ? 0.12 : 0.15)),
          Padding(
            padding: const EdgeInsets.all(48),
            child: FadeTransition(
              opacity: _animController,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _brandBadges(),
                      const SizedBox(height: 40),
                      _heroText(),
                      const SizedBox(height: 16),
                      _heroSubtext(),
                      const SizedBox(height: 40),
                      _featureCards(),
                      const SizedBox(height: 10),
                      CommunitySectionWidget(isDesktop: true, urls: _communityUrls(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientOrb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _brandBadges() {
    return _glassPill(AppConstants.appName, const Color(0xFFA5B4FC));
  }

  Widget _glassPill(String text, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor, letterSpacing: -0.2),
      ),
    );
  }

  Widget _heroText() {
    return Text(
      S.of(context).login_brand_headline,
      style: const TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.1,
        letterSpacing: -1.5,
      ),
    );
  }

  Widget _heroSubtext() {
    return Text(
      S.of(context).login_brand_description,
      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.55), height: 1.65),
    );
  }

  Widget _featureCards() {
    final l10n = S.of(context);
    return Column(
      children: [
        _glassFeatureCard(Icons.shield_outlined, l10n.login_feature_auth_title, l10n.login_feature_auth_description),
        const SizedBox(height: 10),
        _glassFeatureCard(
          Icons.key_off_outlined,
          l10n.login_feature_credentials_title,
          l10n.login_feature_credentials_description,
        ),
        const SizedBox(height: 10),
        _glassFeatureCard(
          Icons.table_chart_outlined,
          l10n.login_feature_query_title,
          l10n.login_feature_query_description,
        ),
      ],
    );
  }

  Widget _glassFeatureCard(IconData icon, String title, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFFA5B4FC)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formPanel(BuildContext context, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: FadeTransition(
                  opacity: _animController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _brandIcon(isDark),
                      const SizedBox(height: 36),
                      _formHeading(context),
                      const SizedBox(height: 32),
                      // The brand panel already shows the desktop community section.
                      _formBody(context, isDark, showCommunity: false),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(top: 16, right: 16, child: _themeBadge(isDark)),
        ],
      ),
    );
  }

  Widget _brandIcon(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest : cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Icon(Icons.bolt_rounded, size: 24, color: cs.onSurface),
    );
  }

  Widget _formHeading(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).login_welcome_title,
          style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8, color: cs.onSurface),
        ),
        const SizedBox(height: 8),
        Text(S.of(context).login_sso_subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _formBody(BuildContext context, bool isDark, {required bool showCommunity}) {
    return _ssoFormBody(context, context.read<AuthMode>(), showCommunity: showCommunity);
  }

  /// The sign-in: the error line and the sign-in buttons, which a misconfigured build leaves out. A build without a
  /// Platform target shows the single sign-on button; one with a Platform target shows a Studio and a Platform button
  /// of equal weight, each with its helper text.
  Widget _ssoFormBody(BuildContext context, AuthMode mode, {required bool showCommunity}) {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ssoErrorLine(mode),
        if (mode is OidcAuthMode)
          switch (_entries) {
            [_] => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: SizedBox(
                width: double.infinity,
                child: _entryButton(context, SessionTarget.studio, loginButtonSsoKey, l10n.login_sso_button),
              ),
            ),
            _ => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _entry(
                  context,
                  _entryButton(context, SessionTarget.studio, loginButtonSsoKey, l10n.login_studio_button),
                  l10n.login_studio_helper,
                ),
                const SizedBox(height: 20),
                _entry(
                  context,
                  _entryButton(context, SessionTarget.platform, loginButtonPlatformKey, l10n.login_platform_button),
                  l10n.login_platform_helper,
                ),
              ],
            ),
          },
        const SizedBox(height: 28),
        if (showCommunity) ...[
          const SizedBox(height: 4),
          CommunitySectionWidget(isDesktop: false, urls: _communityUrls(context)),
        ],
        const SizedBox(height: 16),
        _versionText(context),
      ],
    );
  }

  /// The error that the single sign-on page shows in [state], or null: the sign-in's own error, else the startup
  /// sign-in error until the first tap, else the configuration error of a misconfigured build. Nothing shows while a
  /// sign-in runs or once it has succeeded.
  AppErrorCode? _ssoErrorCode(AuthMode mode, LoginState state) => switch (state) {
    LoginErrorState(:final errorCode) => errorCode,
    LoginLoadingState() || LoginLoadedState() => null,
    LoginInitialState() =>
      (_ssoTapped ? null : widget.startupSignInError) ??
          (mode is OidcMisconfiguredAuthMode ? AppErrorCode.authOidcConfig : null),
  };

  Widget _ssoErrorLine(AuthMode mode) {
    return BlocBuilder<LoginBloc, LoginState>(
      builder: (context, state) => switch (_ssoErrorCode(mode, state)) {
        final errorCode? => Center(
          child: Text(
            errorCode.resolve(context),
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
        null => const SizedBox.shrink(),
      },
    );
  }

  /// A full-width sign-in [button] with its [helper] text below it.
  Widget _entry(BuildContext context, Widget button, String helper) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: double.infinity, child: button),
        const SizedBox(height: 8),
        Text(helper, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4)),
      ],
    );
  }

  /// The sign-in button of [target]: every button is disabled while a sign-in runs, and only the one of the running
  /// sign-in's target shows the spinner.
  Widget _entryButton(BuildContext context, SessionTarget target, Key key, String label) {
    return BlocBuilder<LoginBloc, LoginState>(
      buildWhen: (previous, current) => previous.runtimeType != current.runtimeType,
      builder: (context, state) {
        final isLoading = state is LoginLoadingState;
        final showsSpinner = state is LoginLoadingState && state.target == target;
        return FilledButton(
          key: key,
          onPressed: isLoading ? null : () => _onSsoTapped(context, target),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: showsSpinner
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                  )
                : Text(label),
          ),
        );
      },
    );
  }

  void _onSsoTapped(BuildContext context, SessionTarget target) {
    setState(() => _ssoTapped = true);
    _requestSso(context, target);
  }

  /// Starts the single sign-on for [target]. The page reads the route's `returnUrl` on the way out.
  void _requestSso(BuildContext context, SessionTarget target) =>
      context.read<LoginBloc>().add(SsoSignInRequested(target: target));

  /// The links of the community section.
  CommunityUrls _communityUrls(BuildContext context) => CommunityUrls.of(context.read<ProjectLinks>());

  Widget _versionText(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'v${AppConstants.appVersion}+${AppConstants.appBuildNumber}',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _themeBadge(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    final badge = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: radius,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 18, color: cs.onSurfaceVariant),
    );

    final onToggle = widget.onToggleTheme;
    if (onToggle == null) return badge;

    return Tooltip(
      message: isDark ? S.of(context).login_switch_to_light_mode : S.of(context).login_switch_to_dark_mode,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onToggle, borderRadius: radius, child: badge),
      ),
    );
  }

  void _onLoginStateChange(BuildContext context, LoginState state) {
    if (state is LoginLoadingState) {
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(S.of(context).loading),
          backgroundColor: Theme.of(context).colorScheme.primary,
          width: MediaQuery.of(context).size.width * 0.8,
        ),
      );
    } else if (state is LoginLoadedState) {
      // Honor `?returnUrl=` from the redirect-to-login flow so deep
      // links survive the auth bounce. Open-redirect guard rejects
      // off-origin candidates, a returnUrl that is too long, holds a
      // control character or is the login page, and a returnUrl that
      // belongs to the other target's shell; falls back to the home of
      // the signed-in target.
      final target = state.target;
      final returnUrl = GoRouterState.of(context).uri.queryParameters['returnUrl'];
      final safePath = safeReturnPath(returnUrl, loginPath: ApplicationRoutesConstants.login);
      final destination = safePath != null && ApplicationRoutesConstants.belongsTo(target, safePath)
          ? safePath
          : ApplicationRoutesConstants.homeFor(target);
      context.go(destination);
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).hideCurrentSnackBar();
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(S.of(context).success),
          backgroundColor: Theme.of(context).colorScheme.primary,
          width: MediaQuery.of(context).size.width * 0.8,
        ),
      );
    } else if (state is LoginErrorState) {
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).hideCurrentSnackBar();
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(state.errorCode.resolve(context)),
          backgroundColor: Theme.of(context).colorScheme.error,
          width: MediaQuery.of(context).size.width * 0.8,
        ),
      );
    }
  }
}
