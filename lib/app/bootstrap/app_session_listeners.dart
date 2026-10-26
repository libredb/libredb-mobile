import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/session/session_cubit.dart';
import 'package:libredb_mobile/app/session/platform_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/security/idle_timeout_observer.dart';
import 'package:libredb_mobile/features/app_lock/application/app_lock_bloc.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/session_target_switch_bloc.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/auth/domain/entities/session_target_switch_result.dart';
import 'package:libredb_mobile/features/auth/domain/services/sso_auto_redirect_gate.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/cached_object_browser_repository.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/studio/cached_provider_meta_repository.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';

class AppSessionListeners extends StatefulWidget {
  const AppSessionListeners({
    super.key,
    required this.scaffoldMessengerKey,
    required this.child,
    this.idleTimeoutOverride,
  });

  /// The ScaffoldMessenger of the MaterialApp in [child], which shows the
  /// session notices: the idle timeout, and a logout that could not remove
  /// all stored data. This widget sits above MaterialApp, where its context
  /// finds no ScaffoldMessenger.
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  final Widget child;

  /// Test seam — lets a widget test inject a smaller threshold than the
  /// injected [AppConfig]. Null falls back to the [AppConfig.idleTimeout]
  /// read from the widget tree via [context.read<AppConfig>()].
  final Duration? idleTimeoutOverride;

  @override
  State<AppSessionListeners> createState() => _AppSessionListenersState();
}

class _AppSessionListenersState extends State<AppSessionListeners> {
  static final _log = AppLogger.getLogger('AppSessionListeners');

  IdleTimeoutObserver? _idleObserver;

  /// The session state before the one the app lock listener handles, starting as [SessionCubit] starts.
  SessionState _lastSession = const SessionUnknown();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _idleObserver?.stop();
    _idleObserver = null;
    super.dispose();
  }

  void _startIdleObserver() {
    if (_idleObserver != null) return;
    final threshold = widget.idleTimeoutOverride ?? context.read<AppConfig>().idleTimeout;
    if (threshold == null) {
      _log.debug('idle timeout disabled (no threshold configured)');
      return;
    }
    final cubit = context.read<SessionCubit>();
    final observer = IdleTimeoutObserver(
      idleThreshold: threshold,
      onTimeout: () {
        _log.info('idle timeout fired — signing out');
        cubit.endSession(reason: SessionExpiredReason.idleTimeout);
      },
    );
    observer.start();
    _idleObserver = observer;
  }

  /// Counts a key the user pressed as activity, as typing in a form or moving the focus with a hardware keyboard
  /// does. Returns false, so the key still reaches the focused widget. A key event Flutter synthesized to
  /// match the keyboard state, such as the release of a key held down when the window lost focus, is no activity.
  bool _onKeyEvent(KeyEvent event) {
    if (!event.synthesized) _idleObserver?.recordActivity();
    return false;
  }

  void _stopIdleObserver() {
    _idleObserver?.stop();
    _idleObserver = null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<LoginBloc, LoginState>(
          listenWhen: (previous, current) => previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            if (state case LoginLoadedState(:final target)) {
              // Mark the session authenticated SYNCHRONOUSLY. As an ancestor
              // of the login page this listener fires before the page's
              // success listener, so the session is already authenticated
              // when that listener navigates to the `returnUrl` deep link.
              // Awaiting a storage read here would let navigation win the
              // race and bounce the deep link back to /login → home.
              context.read<SessionCubit>().markAuthenticated(target);
            }
          },
        ),
        BlocListener<SignOutBloc, SignOutState>(
          listenWhen: (previous, current) => previous is! SignOutDone && current is SignOutDone,
          listener: (context, state) {
            context.read<SessionCubit>().markLoggedOut();
            _closeSsoAutoRedirect(context);
            // SignOutBloc signs out with stored data left when the logout could not remove all stored data, and with
            // the provider session left when the app could not end the session at the identity provider.
            switch (state) {
              case SignedOutWithDataLeft():
                _showNotice((strings) => strings.logout_stored_data_left);
              case SignedOutWithProviderSessionLeft():
                _showNotice((strings) => strings.error_auth_oidc_logout_incomplete);
              case SignOutInitial() || SignOutInProgress() || SignedOut():
                break;
            }
          },
        ),
        // The sign-out ends before the provider logout has ended, and tells afterwards when the
        // provider logout failed.
        BlocListener<SignOutBloc, SignOutState>(
          listenWhen: (previous, current) => previous is SignedOut && current is SignedOutWithProviderSessionLeft,
          listener: (context, state) => _showNotice((strings) => strings.error_auth_oidc_logout_incomplete),
        ),
        // A mode switch the other target's gate accepted opens that mode; a refused one keeps the session and says why.
        BlocListener<SessionTargetSwitchBloc, SessionTargetSwitchState>(
          listener: (context, state) {
            switch (state) {
              case SessionTargetSwitchSucceeded(:final result):
                _completeSwitch(context, result);
              case SessionTargetSwitchRefusedState(:final errorCode):
                _tellSwitchRefused(context, errorCode);
              case SessionTargetSwitchIdle() || SessionTargetSwitchInProgress() || SessionTargetSwitchAbandonedState():
                break;
            }
          },
        ),
        // The favorites are kept per subject: Studio's answer names whose to show, and the sign-out, which clears the
        // answer, hides them until the next user is known.
        BlocListener<StudioIdentityCubit, StudioIdentityState>(
          listener: (context, state) {
            final favorites = context.read<FavoriteConnectionsBloc>();
            switch (state) {
              case StudioIdentityLoaded(:final identity):
                favorites.add(FavoriteConnectionsSubjectChanged(identity.subject));
              case StudioIdentityInitial():
                favorites.add(const FavoriteConnectionsSubjectChanged(null));
              case StudioIdentityLoading() || StudioIdentityFailure():
                break;
            }
          },
        ),
        // Studio's answer names the subject the active connection and database are remembered for.
        BlocListener<StudioIdentityCubit, StudioIdentityState>(
          listenWhen: (previous, current) => current is StudioIdentityLoaded,
          listener: (context, state) {
            final subject = (state as StudioIdentityLoaded).identity.subject;
            context.read<ActiveConnectionCubit>().signedIn(subject);
            context.read<ActiveCatalogCubit>().signedIn(subject);
          },
        ),
        // A switch drops the cached object answers past their time and keeps the fresh ones, so going back to a
        // connection soon sends no request.
        BlocListener<ActiveConnectionCubit, ActiveConnectionState>(
          listenWhen: (previous, current) =>
              current.connection != null && previous.connection?.id != current.connection!.id,
          listener: (context, state) => context.read<CachedObjectBrowserRepository>().evictExpired(),
        ),
        // A vanished connection loses every cached answer, so a grant given back later is read afresh.
        BlocListener<ActiveConnectionCubit, ActiveConnectionState>(
          listenWhen: (previous, current) => current is ActiveConnectionVanished,
          listener: (context, state) {
            final id = (state as ActiveConnectionVanished).vanished.id;
            context.read<CachedObjectBrowserRepository>().invalidate(id);
            context.read<CachedProviderMetaRepository>().invalidate(id);
          },
        ),
        // The app lock locks a cold start that restores a session, opens unlocked after a sign-in at the identity
        // provider, and never covers the login page.
        BlocListener<SessionCubit, SessionState>(
          listenWhen: (previous, current) => previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            final previous = _lastSession;
            _lastSession = state;
            final lock = context.read<AppLockBloc>();
            switch (state) {
              case SessionAuthenticated() when _isRestore(previous):
                lock.add(const AppLockSessionRestored());
              case SessionAuthenticated():
                lock.add(const AppLockSignedIn());
              case SessionUnauthenticated():
                lock.add(const AppLockSignedOut());
              case SessionUnknown():
                break;
            }
          },
        ),
        BlocListener<SessionCubit, SessionState>(
          listenWhen: (previous, current) => previous.runtimeType != current.runtimeType,
          listener: (context, state) {
            switch (state) {
              case SessionAuthenticated():
                _startIdleObserver();
                _closeSsoAutoRedirect(context);
              case SessionUnauthenticated(:final reason):
                _stopIdleObserver();
                _forgetSignedOutUser(context);
                if (reason == SessionExpiredReason.idleTimeout) {
                  _showNotice((strings) => strings.idle_timeout_signed_out);
                }
                // The stored session is still being read and may open the app when it answers, so the login page
                // must not send the user to the identity provider meanwhile.
                if (reason == SessionExpiredReason.storageTimeout) _closeSsoAutoRedirect(context);
              case SessionUnknown():
                break;
            }
          },
        ),
      ],
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _idleObserver?.recordActivity(),
        onPointerMove: (_) => _idleObserver?.recordActivity(),
        // A mouse wheel and a trackpad scroll the page without a pointer down or move.
        onPointerSignal: (_) => _idleObserver?.recordActivity(),
        onPointerPanZoomStart: (_) => _idleObserver?.recordActivity(),
        onPointerPanZoomUpdate: (_) => _idleObserver?.recordActivity(),
        child: widget.child,
      ),
    );
  }

  /// Whether a session that follows [previous] comes from the stored session, not from a sign-in: the restore at
  /// start, or its late answer after the restore time limit signed the user out.
  static bool _isRestore(SessionState previous) => switch (previous) {
    SessionUnknown() => true,
    SessionUnauthenticated(:final reason) => reason == SessionExpiredReason.storageTimeout,
    SessionAuthenticated() => false,
  };

  /// The app-scoped blocs and caches outlive the session, so the next user to sign in would see what they hold about
  /// the one who signed out: the sign-in form state, a password shown in plain text among it, who Studio said the user
  /// was, with the role, what it allowed them, whether it refused their account, the connection and database they had
  /// open, and the provider-meta and object browser answers kept in memory; and who Platform said the admin was and
  /// whether it refused them.
  ///
  /// Every Platform feature BLoC is created in its route or page, so it is disposed with the Platform shell; a later
  /// app-scoped Platform BLoC or cubit must be cleared here.
  void _forgetSignedOutUser(BuildContext context) {
    context.read<LoginBloc>().add(const LoginReset());
    context.read<StudioIdentityCubit>().clear();
    context.read<ConnectionPolicyCubit>().clear();
    context.read<StudioAccountRefusalCubit>().clear();
    context.read<PlatformIdentityCubit>().clear();
    context.read<PlatformAccountRefusalCubit>().clear();
    context.read<ActiveConnectionCubit>().clear();
    context.read<ActiveCatalogCubit>().clear();
    context.read<CachedObjectBrowserRepository>().clear();
    context.read<CachedProviderMetaRepository>().clear();
  }

  /// Opens the mode a switch moved the session to, while the session is still signed in to the mode it left.
  ///
  /// A switch is no sign-out: it clears only the in-memory state of the mode it leaves, as [_forgetSignedOutUser] does
  /// for that mode, fills the identity of the mode it opens from the gate's answer, and then marks the session
  /// authenticated for the new target, so the router opens its home. It removes no stored data, leaves the sign-in
  /// form alone, sends no Studio logout record and starts no provider end-session. The session stays
  /// [SessionAuthenticated], so the app lock gets no event and the idle timeout keeps running. A session that ended or
  /// moved while the gate was asked is left as it is.
  void _completeSwitch(BuildContext context, SessionTargetSwitchResult result) {
    final (SessionTarget from, SessionTarget to) = switch (result) {
      SwitchedToStudio() => (SessionTarget.platform, SessionTarget.studio),
      SwitchedToPlatform() => (SessionTarget.studio, SessionTarget.platform),
      SessionTargetSwitchRefused() => throw StateError('A refused switch has no mode to open'),
      SessionTargetSwitchAbandoned() => throw StateError('An abandoned switch has no mode to open'),
    };
    final session = context.read<SessionCubit>();
    if (session.state != SessionAuthenticated(target: from)) {
      _log.info('The session is no longer signed in to {}, so the switch to {} opens nothing', [from.name, to.name]);
      return;
    }
    switch (result) {
      case SwitchedToPlatform(:final identity):
        context.read<StudioIdentityCubit>().clear();
        context.read<ConnectionPolicyCubit>().clear();
        context.read<StudioAccountRefusalCubit>().clear();
        context.read<ActiveConnectionCubit>().clear();
        context.read<ActiveCatalogCubit>().clear();
        context.read<CachedObjectBrowserRepository>().clear();
        context.read<CachedProviderMetaRepository>().clear();
        context.read<PlatformIdentityCubit>().signedIn(identity);
      case SwitchedToStudio(:final identity):
        context.read<PlatformIdentityCubit>().clear();
        context.read<PlatformAccountRefusalCubit>().clear();
        context.read<StudioIdentityCubit>().signedIn(identity);
      case SessionTargetSwitchRefused() || SessionTargetSwitchAbandoned():
        break;
    }
    session.markAuthenticated(to);
  }

  /// Tells the user, in the mode they stayed in, why the other target's gate refused the switch. A session that ended
  /// while the gate was asked has its own notice. The other target's 401 does not end the session, so its refusal names
  /// the mode the user stays in instead of the login page's text, which asks for a sign-in.
  void _tellSwitchRefused(BuildContext context, AppErrorCode errorCode) {
    if (context.read<SessionCubit>().state is! SessionAuthenticated) return;
    final messenger = widget.scaffoldMessengerKey.currentState;
    if (messenger == null) {
      throw StateError('No ScaffoldMessenger is mounted with scaffoldMessengerKey to show a session notice');
    }
    final message = switch (errorCode) {
      AppErrorCode.platformAdminRoleRequired => S.of(messenger.context).profile_switch_admin_role_required,
      AppErrorCode.platformAccountRefused => S.of(messenger.context).profile_switch_platform_refused,
      AppErrorCode.studioAccountRefused => S.of(messenger.context).profile_switch_studio_refused,
      AppErrorCode.studioUnreachable => S.of(messenger.context).profile_switch_studio_unreachable,
      _ => errorCode.resolve(messenger.context),
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Stops the login page of an `oidc` build from sending the user to the identity provider on its own for the rest of
  /// the run, once the run has been signed in, the user has logged out, or the stored session is read past the restore
  /// time limit. Only [OidcAuthMode] provides the gate, so the other modes skip it.
  void _closeSsoAutoRedirect(BuildContext context) {
    if (context.read<AuthMode>() is OidcAuthMode) context.read<SsoAutoRedirectGate>().close();
  }

  /// Shows the [message] of a session ending through the ScaffoldMessenger of the MaterialApp, so it stays on screen
  /// when the login page opens.
  void _showNotice(String Function(S strings) message) {
    final messenger = widget.scaffoldMessengerKey.currentState;
    if (messenger == null) {
      throw StateError('No ScaffoldMessenger is mounted with scaffoldMessengerKey to show a session notice');
    }
    messenger.showSnackBar(SnackBar(content: Text(message(S.of(messenger.context)))));
  }
}
