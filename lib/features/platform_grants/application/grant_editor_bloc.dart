import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/put_grant_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/grant_subject.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/grant_target.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'grant_editor_event.dart';
part 'grant_editor_state.dart';

/// The form that gives a user access to a connection, or changes the level or expiry of the grant the user holds;
/// both are the same Platform call, `PUT /api/v1/connections/{id}/grants/{subject}`.
///
/// The form is checked before sending: a level must be picked, `write` only on a connection with a write credential,
/// and an expiry must be after now; Platform's clock still decides in the end. A save while one runs is dropped, so a
/// double tap sends one `PUT`, and nothing is ever sent again on its own: after Keycloak did not answer, only Retry
/// sends the `PUT` again, checked and built from what the form shows then. Every refusal keeps the form and its values.
///
/// No log line carries the subject, a username or an e-mail address.
class GrantEditorBloc extends Bloc<GrantEditorEvent, GrantEditorState> {
  GrantEditorBloc({
    required this._putGrantUseCase,
    required GrantTarget target,
    DirectoryUser? user,
    PlatformGrant? grant,
    Clock? clock,
  }) : _clock = clock ?? const Clock(),
       super(_initial(target, user, grant, (clock ?? const Clock()).now())) {
    on<GrantEditorLevelChanged>(_onLevelChanged);
    on<GrantEditorExpiryChanged>(_onExpiryChanged);
    on<GrantEditorSaveRequested>(_onSave, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('GrantEditorBloc');

  static const levels = ['read', 'write'];

  final PutGrantUseCase _putGrantUseCase;
  final Clock _clock;

  /// The form for a new grant to [user], or for changing [grant], prefilled from it; [user] may come with [grant] when
  /// the admin picked a user who already holds one.
  static GrantEditorState _initial(GrantTarget target, DirectoryUser? user, PlatformGrant? grant, DateTime now) {
    assert(user != null || grant != null, 'the editor needs a user or a grant');
    final subject = user != null ? GrantSubject.ofUser(user) : GrantSubject.ofGrant(grant!);
    final level = grant == null ? 'read' : (levels.contains(grant.level) ? grant.level : null);
    final expiresAt = grant?.expiresAt;
    return GrantEditorState(
      target: target,
      subject: subject,
      isEdit: grant != null,
      level: level,
      expiresAt: expiresAt,
      levelIssue: level == 'write' && !target.hasWriteCredential ? GrantLevelIssue.writeUnavailable : null,
      expiryIssue: expiresAt != null && !expiresAt.isAfter(now) ? GrantExpiryIssue.notInFuture : null,
    );
  }

  void _onLevelChanged(GrantEditorLevelChanged event, Emitter<GrantEditorState> emit) {
    if (!levels.contains(event.level)) return;
    emit(
      state._copyWith(
        level: () => event.level,
        levelIssue: () =>
            event.level == 'write' && !state.target.hasWriteCredential ? GrantLevelIssue.writeUnavailable : null,
      ),
    );
  }

  void _onExpiryChanged(GrantEditorExpiryChanged event, Emitter<GrantEditorState> emit) {
    final value = event.expiresAt;
    // Whole minutes: the picker offers no seconds, and a grant ends on the minute.
    final expiresAt = value == null
        ? null
        : value.isUtc
        ? DateTime.utc(value.year, value.month, value.day, value.hour, value.minute)
        : DateTime(value.year, value.month, value.day, value.hour, value.minute);
    emit(state._copyWith(expiresAt: () => expiresAt, expiryIssue: () => null));
  }

  Future<void> _onSave(GrantEditorSaveRequested event, Emitter<GrantEditorState> emit) async {
    // Retry sends what the form shows now, not what was sent before: a field may have changed since the 503.
    if (event is GrantEditorRetryRequested && state.banner != GrantEditorBanner.retry) return;
    final level = state.level;
    final expiresAt = state.expiresAt;
    final levelIssue = level == null
        ? GrantLevelIssue.missing
        : level == 'write' && !state.target.hasWriteCredential
        ? GrantLevelIssue.writeUnavailable
        : null;
    final expiryIssue = expiresAt != null && !expiresAt.isAfter(_clock.now()) ? GrantExpiryIssue.notInFuture : null;
    if (levelIssue != null || expiryIssue != null || level == null) {
      emit(state._copyWith(levelIssue: () => levelIssue, expiryIssue: () => expiryIssue));
      return;
    }
    final request = (level: level, expiresAt: expiresAt);

    emit(
      state._copyWith(
        status: GrantEditorStatus.submitting,
        levelIssue: () => null,
        expiryIssue: () => null,
        subjectRefused: false,
        formError: () => null,
        bannerCode: () => null,
      ),
    );
    final result = await _putGrantUseCase(
      state.target.connectionId,
      state.subject.subject,
      level: request.level,
      expiresAt: request.expiresAt,
    );
    switch (result) {
      case Success():
        _log.info('save: the grant is saved');
        emit(state._copyWith(status: GrantEditorStatus.saved, mayHaveChanged: true));
      case Failure(:final error):
        // The code only: Platform's message can name the user.
        _log.warn('save failed: {}', [error.code ?? error.runtimeType]);
        final code = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        final editing = state._copyWith(
          status: GrantEditorStatus.editing,
          mayHaveChanged: state.mayHaveChanged || !_clearRefusals.contains(code),
        );
        emit(switch (code) {
          AppErrorCode.platformGrantLevelRefused => editing._copyWith(levelIssue: () => GrantLevelIssue.refused),
          AppErrorCode.platformGrantExpiryRefused => editing._copyWith(expiryIssue: () => GrantExpiryIssue.refused),
          AppErrorCode.platformGrantSubjectRefused => editing._copyWith(subjectRefused: true),
          AppErrorCode.platformLicenseUserSeats ||
          AppErrorCode.platformLicenseExpired ||
          AppErrorCode.platformLicenseInvalid ||
          AppErrorCode.platformDirectoryUnavailable ||
          AppErrorCode.platformKeycloakUnavailable ||
          AppErrorCode.platformNotFound => editing._copyWith(bannerCode: () => code),
          _ => editing._copyWith(formError: () => code),
        });
    }
  }

  /// The codes of an answer that refused the `PUT` before Platform wrote anything; any other failure, such as a
  /// timeout, a lost connection, a 500 or an unreadable 200, may have saved the grant.
  static const _clearRefusals = {
    AppErrorCode.platformGrantLevelRefused,
    AppErrorCode.platformGrantExpiryRefused,
    AppErrorCode.platformGrantSubjectRefused,
    AppErrorCode.platformValidationFailed,
    AppErrorCode.platformLicenseUserSeats,
    AppErrorCode.platformLicenseExpired,
    AppErrorCode.platformLicenseInvalid,
    AppErrorCode.platformDirectoryUnavailable,
    AppErrorCode.platformKeycloakUnavailable,
    AppErrorCode.platformNotFound,
    AppErrorCode.platformAdminRoleRequired,
    AppErrorCode.platformLicenseAdminSeats,
    AppErrorCode.platformApiDisabled,
    AppErrorCode.platformPermissionDenied,
    AppErrorCode.platformNotConfigured,
    AppErrorCode.authInvalidAccessToken,
  };
}
