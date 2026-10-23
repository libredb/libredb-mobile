import 'package:equatable/equatable.dart';

// A port of Studio's masking configuration (`src/lib/data-masking.ts` at libredb-studio c9989a6b5). The phone masks
// with Studio's defaults only: the per-user `masking_config` is not safely readable from the phone (S-08).

/// How a matched value is masked: Studio's `MaskType`.
enum MaskType { email, phone, card, ssn, full, partial, ip, date, financial, custom }

/// One masking rule: the column names it matches and how it masks their values (Studio's `MaskingPattern`).
class MaskingPattern extends Equatable {
  const MaskingPattern({
    required this.id,
    required this.name,
    required this.columnPatterns,
    required this.maskType,
    this.enabled = true,
    this.isBuiltin = false,
    this.customMask,
  });

  final String id;
  final String name;

  /// Regular expressions, each matched case-insensitively against a whole column name.
  final List<String> columnPatterns;
  final MaskType maskType;
  final bool enabled;
  final bool isBuiltin;

  /// The text a [MaskType.custom] rule writes in place of the value.
  final String? customMask;

  @override
  List<Object?> get props => [id, name, columnPatterns, maskType, enabled, isBuiltin, customMask];
}

/// What one role may do with masking (Studio's `roleSettings.admin` and `roleSettings.user`).
class MaskingRoleSettings extends Equatable {
  const MaskingRoleSettings({required this.canToggle, required this.canReveal});

  final bool canToggle;
  final bool canReveal;

  @override
  List<Object?> get props => [canToggle, canReveal];
}

/// Studio's `roleSettings`: the settings of the admin and of every other role.
class MaskingRoleSettingsPair extends Equatable {
  const MaskingRoleSettingsPair({required this.admin, required this.user});

  final MaskingRoleSettings admin;
  final MaskingRoleSettings user;

  @override
  List<Object?> get props => [admin, user];
}

/// Studio's `MaskingConfig`.
class MaskingConfig extends Equatable {
  const MaskingConfig({required this.enabled, required this.patterns, required this.roleSettings});

  /// Masking on or off as a whole.
  final bool enabled;

  /// The rules in order; the first that matches a column wins.
  final List<MaskingPattern> patterns;
  final MaskingRoleSettingsPair roleSettings;

  @override
  List<Object?> get props => [enabled, patterns, roleSettings];
}

/// Studio's `DEFAULT_MASKING_CONFIG` (`src/lib/data-masking.ts:34-153` at c9989a6b5), pinned by
/// `test/shared/security/result_masking/masking_config_test.dart`.
const defaultMaskingConfig = MaskingConfig(
  enabled: true,
  patterns: [
    MaskingPattern(
      id: 'builtin-email',
      name: 'Email',
      columnPatterns: ['email', 'e_mail', 'user_email', 'customer_email', 'contact_email'],
      maskType: MaskType.email,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-password',
      name: 'Password',
      columnPatterns: [
        'password',
        'passwd',
        'pass',
        'pwd',
        'secret',
        'user_password',
        'hashed_password',
        'password_hash',
        'hash',
      ],
      maskType: MaskType.full,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-ssn',
      name: 'SSN',
      columnPatterns: ['ssn', 'social_security', 'social_security_number', 'national_id', 'national_number'],
      maskType: MaskType.ssn,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-card',
      name: 'Credit Card',
      columnPatterns: ['credit_card', 'card_number', 'cc_number', 'card_num', 'pan', 'credit_card_number'],
      maskType: MaskType.card,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-phone',
      name: 'Phone',
      columnPatterns: ['phone', 'phone_number', 'mobile', 'cell', 'telephone', 'tel', 'contact_phone'],
      maskType: MaskType.phone,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-token',
      name: 'Token/Key',
      columnPatterns: [
        'token',
        'access_token',
        'refresh_token',
        'api_key',
        'apikey',
        'api_secret',
        'secret_key',
        'auth_token',
        'bearer_token',
        'session_token',
      ],
      maskType: MaskType.partial,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-address',
      name: 'Address',
      columnPatterns: ['address', 'street', 'street_address', 'home_address', 'billing_address', 'shipping_address'],
      maskType: MaskType.full,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-ip',
      name: 'IP Address',
      columnPatterns: ['ip', 'ip_address', 'client_ip', 'remote_ip', 'source_ip'],
      maskType: MaskType.ip,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-financial',
      name: 'Financial',
      columnPatterns: [
        'salary',
        'income',
        'balance',
        'amount',
        'wage',
        'compensation',
        'net_pay',
        'gross_pay',
        'revenue',
      ],
      maskType: MaskType.financial,
      isBuiltin: true,
    ),
    MaskingPattern(
      id: 'builtin-birthdate',
      name: 'Birthdate',
      columnPatterns: ['birth', 'dob', 'date_of_birth', 'birthdate', 'birth_date', 'birthday'],
      maskType: MaskType.date,
      isBuiltin: true,
    ),
  ],
  roleSettings: MaskingRoleSettingsPair(
    admin: MaskingRoleSettings(canToggle: true, canReveal: true),
    user: MaskingRoleSettings(canToggle: false, canReveal: false),
  ),
);
