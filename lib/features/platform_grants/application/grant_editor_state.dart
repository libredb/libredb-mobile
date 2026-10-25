part of 'grant_editor_bloc.dart';

enum GrantEditorStatus { editing, submitting, saved }

/// Why the level cannot be saved: none is selected, `write` on a connection without a write credential, or Platform
/// refused it.
enum GrantLevelIssue { missing, writeUnavailable, refused }

/// Why the expiry cannot be saved: it is not after now, or Platform refused it by its own clock.
enum GrantExpiryIssue { notInFuture, refused }

/// A refusal shown above the form: the license, Keycloak not answering (with Retry), or a connection that is gone.
enum GrantEditorBanner { license, retry, connectionGone }

/// The grant form, whose fields persist across every status (CLAUDE.md, single state exception 3).
///
/// At most one place shows a refusal Platform answered: under the level, the expiry or the user line, as a form
/// error, or as a banner.
final class GrantEditorState extends Equatable {
  const GrantEditorState({
    required this.target,
    required this.subject,
    required this.isEdit,
    required this.level,
    required this.expiresAt,
    this.status = GrantEditorStatus.editing,
    this.levelIssue,
    this.expiryIssue,
    this.subjectRefused = false,
    this.formError,
    this.bannerCode,
    this.mayHaveChanged = false,
  });

  final GrantTarget target;
  final GrantSubject subject;

  /// Whether the subject already holds a grant on the connection, which this form changes.
  final bool isEdit;

  /// `read`, `write`, or null while none is selected.
  final String? level;

  /// The local date and time the grant ends, or null for one that does not expire.
  final DateTime? expiresAt;

  final GrantEditorStatus status;
  final GrantLevelIssue? levelIssue;
  final GrantExpiryIssue? expiryIssue;

  /// Platform refused the subject: Keycloak no longer knows the user, or the user is disabled.
  final bool subjectRefused;

  /// A refusal shown under the form, via `formError.resolve(context)`.
  final AppErrorCode? formError;

  /// The code of the banner above the form, null when none shows.
  final AppErrorCode? bannerCode;

  /// Whether a `PUT` saved the grant or ended without a clear refusal, so the grants list must be read again.
  final bool mayHaveChanged;

  GrantEditorBanner? get banner => switch (bannerCode) {
    AppErrorCode.platformLicenseUserSeats ||
    AppErrorCode.platformLicenseExpired ||
    AppErrorCode.platformLicenseInvalid => GrantEditorBanner.license,
    AppErrorCode.platformDirectoryUnavailable || AppErrorCode.platformKeycloakUnavailable => GrantEditorBanner.retry,
    AppErrorCode.platformNotFound => GrantEditorBanner.connectionGone,
    _ => null,
  };

  /// `write` cannot be picked on a connection without a write credential.
  bool get writeAvailable => target.hasWriteCredential;

  GrantEditorState _copyWith({
    String? Function()? level,
    DateTime? Function()? expiresAt,
    GrantEditorStatus? status,
    GrantLevelIssue? Function()? levelIssue,
    GrantExpiryIssue? Function()? expiryIssue,
    bool? subjectRefused,
    AppErrorCode? Function()? formError,
    AppErrorCode? Function()? bannerCode,
    bool? mayHaveChanged,
  }) => GrantEditorState(
    target: target,
    subject: subject,
    isEdit: isEdit,
    level: level == null ? this.level : level(),
    expiresAt: expiresAt == null ? this.expiresAt : expiresAt(),
    status: status ?? this.status,
    levelIssue: levelIssue == null ? this.levelIssue : levelIssue(),
    expiryIssue: expiryIssue == null ? this.expiryIssue : expiryIssue(),
    subjectRefused: subjectRefused ?? this.subjectRefused,
    formError: formError == null ? this.formError : formError(),
    bannerCode: bannerCode == null ? this.bannerCode : bannerCode(),
    mayHaveChanged: mayHaveChanged ?? this.mayHaveChanged,
  );

  @override
  List<Object?> get props => [
    target,
    subject,
    isEdit,
    level,
    expiresAt,
    status,
    levelIssue,
    expiryIssue,
    subjectRefused,
    formError,
    bannerCode,
    mayHaveChanged,
  ];

  /// No subject: this text can reach a log.
  @override
  String toString() =>
      'GrantEditorState(status: ${status.name}, isEdit: $isEdit, level: $level, expiresAt: $expiresAt, '
      'levelIssue: ${levelIssue?.name}, expiryIssue: ${expiryIssue?.name}, subjectRefused: $subjectRefused, '
      'formError: ${formError?.key}, bannerCode: ${bannerCode?.key}, mayHaveChanged: $mayHaveChanged)';
}
