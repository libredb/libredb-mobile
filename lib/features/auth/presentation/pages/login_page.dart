import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/security/safe_redirect.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/config/project_links.dart';
import 'package:go_router/go_router.dart';

import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/utils/app_constants.dart';

import '../../application/login_bloc.dart';
import '../../domain/services/sign_in_entries.dart';
import '../../domain/services/sso_auto_redirect_gate.dart';
import '../../../../generated/l10n.dart';
import '../widgets/login_brand_icon.dart';
import '../widgets/login_brand_panel.dart';
import '../widgets/login_heading.dart';
import '../widgets/sign_in_entry.dart';
import '../widgets/sign_in_error_line.dart';
import '../widgets/login_theme_badge.dart';
import '../../../../shared/widgets/app_version_label.dart';
import '../../../../shared/widgets/community/community_actions.dart';
import '../../../../shared/widgets/community/community_chip_row.dart';
import '../../../../shared/widgets/community/community_urls.dart';

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
  List<SessionTarget> get _entries => signInEntriesFor(context.read<AppConfig>().platform);

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
            final isDesktop = AppBreakpoints.isDesktop(constraints.maxWidth);
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
    // Scheduled for the end of the frame this page mounted in, which the page may already have left — the router
    // replaces `/login` the moment a session restores. Every read below would throw then.
    if (!mounted) return;
    final mode = context.read<AuthMode>();
    final target = autoRedirectTarget(
      mode: mode,
      entries: _entries,
      gateIsOpen: () => context.read<SsoAutoRedirectGate>().isOpen,
      hasError: () =>
          signInErrorCode(
            mode: mode,
            state: context.read<LoginBloc>().state,
            startupError: widget.startupSignInError,
            tapped: _ssoTapped,
          ) !=
          null,
    );
    if (target == null) return;
    context.read<SsoAutoRedirectGate>().close();
    _requestSso(context, target);
  }

  Widget _desktopLayout(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 55,
          child: LoginBrandPanel(isDark: isDark, urls: _communityUrls(context), fade: _animController),
        ),
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
                    LoginBrandIcon(isDark: isDark),
                    const SizedBox(height: 32),
                    LoginHeading(title: AppConstants.appName, subtitle: S.of(context).login_brand_description),
                    const SizedBox(height: 32),
                    _formBody(context, isDark, showCommunity: true),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: LoginThemeBadge(isDark: isDark, onToggleTheme: widget.onToggleTheme),
        ),
      ],
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
                      LoginBrandIcon(isDark: isDark),
                      const SizedBox(height: 36),
                      LoginHeading(
                        title: S.of(context).login_welcome_title,
                        subtitle: S.of(context).login_sso_subtitle,
                      ),
                      const SizedBox(height: 32),
                      // The brand panel already shows the desktop community section.
                      _formBody(context, isDark, showCommunity: false),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: LoginThemeBadge(isDark: isDark, onToggleTheme: widget.onToggleTheme),
          ),
        ],
      ),
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
        SignInErrorLine(mode: mode, startupError: widget.startupSignInError, tapped: _ssoTapped),
        if (mode is OidcAuthMode)
          switch (_entries) {
            // The lone entry of a build without a Platform target carries no helper line and does not gate itself:
            // the status page above the login screen already holds the user back when Studio does not answer.
            [_] => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: SignInEntry(
                target: SessionTarget.studio,
                buttonKey: loginButtonSsoKey,
                label: l10n.login_sso_button,
                helper: null,
                showsReachability: false,
                onTap: (target) => _onSsoTapped(context, target),
              ),
            ),
            _ => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                SignInEntry(
                  target: SessionTarget.studio,
                  buttonKey: loginButtonSsoKey,
                  label: l10n.login_studio_button,
                  helper: l10n.login_studio_helper,
                  showsReachability: true,
                  onTap: (target) => _onSsoTapped(context, target),
                ),
                const SizedBox(height: 20),
                SignInEntry(
                  target: SessionTarget.platform,
                  buttonKey: loginButtonPlatformKey,
                  label: l10n.login_platform_button,
                  helper: l10n.login_platform_helper,
                  showsReachability: true,
                  onTap: (target) => _onSsoTapped(context, target),
                ),
              ],
            ),
          },
        const SizedBox(height: 28),
        if (showCommunity) ...[
          const SizedBox(height: 4),
          CommunityChipRow(actions: communityActions(_communityUrls(context))),
        ],
        const SizedBox(height: 16),
        const AppVersionLabel(),
      ],
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
  /// The community links of this build's [ProjectLinks].
  ///
  /// The mapping lives here rather than on `CommunityUrls`: that class is under `shared/`, which imports `core/`
  /// only, and `ProjectLinks` is `infrastructure/config/` (`test/architecture/import_guard_test.dart`).
  CommunityUrls _communityUrls(BuildContext context) {
    final links = context.read<ProjectLinks>();
    return CommunityUrls(repo: links.repositoryUrl, sponsor: links.sponsorUrl, docs: links.docsUrl);
  }

  void _onLoginStateChange(BuildContext context, LoginState state) {
    if (state is LoginLoadedState) {
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
    }
  }
}
