import 'package:libredb_mobile/shared/security/result_masking/masking_config.dart';

// The configurations of Studio's tests/fixtures/masking-configs.ts at libredb-studio c9989a6b5, which the ported tests
// read.

const _patterns = [
  MaskingPattern(
    id: 'builtin-email',
    name: 'Email',
    columnPatterns: ['email', 'e_mail', 'user_email'],
    maskType: MaskType.email,
    isBuiltin: true,
  ),
  MaskingPattern(
    id: 'builtin-ssn',
    name: 'SSN',
    columnPatterns: ['ssn', 'social_security'],
    maskType: MaskType.ssn,
    isBuiltin: true,
  ),
  MaskingPattern(
    id: 'builtin-card',
    name: 'Credit Card',
    columnPatterns: ['credit_card', 'card_number'],
    maskType: MaskType.card,
    isBuiltin: true,
  ),
  MaskingPattern(
    id: 'builtin-phone',
    name: 'Phone',
    columnPatterns: ['phone', 'mobile'],
    maskType: MaskType.phone,
    isBuiltin: true,
  ),
  MaskingPattern(
    id: 'builtin-financial',
    name: 'Financial',
    columnPatterns: ['salary', 'income', 'balance'],
    maskType: MaskType.financial,
    isBuiltin: true,
  ),
];

const _roleSettings = MaskingRoleSettingsPair(
  admin: MaskingRoleSettings(canToggle: true, canReveal: true),
  user: MaskingRoleSettings(canToggle: false, canReveal: false),
);

const maskingConfigEnabled = MaskingConfig(enabled: true, patterns: _patterns, roleSettings: _roleSettings);

const maskingConfigDisabled = MaskingConfig(enabled: false, patterns: _patterns, roleSettings: _roleSettings);

const maskingConfigUserCanToggle = MaskingConfig(
  enabled: true,
  patterns: _patterns,
  roleSettings: MaskingRoleSettingsPair(
    admin: MaskingRoleSettings(canToggle: true, canReveal: true),
    user: MaskingRoleSettings(canToggle: true, canReveal: true),
  ),
);

final maskingConfigAllDisabledPatterns = MaskingConfig(
  enabled: true,
  patterns: [
    for (final p in _patterns)
      MaskingPattern(
        id: p.id,
        name: p.name,
        columnPatterns: p.columnPatterns,
        maskType: p.maskType,
        enabled: false,
        isBuiltin: p.isBuiltin,
      ),
  ],
  roleSettings: _roleSettings,
);

const maskingConfigWithCustom = MaskingConfig(
  enabled: true,
  patterns: [
    ..._patterns,
    MaskingPattern(
      id: 'custom-1',
      name: 'Custom Secret',
      columnPatterns: ['secret_field', r'internal_.*'],
      maskType: MaskType.custom,
      customMask: '[REDACTED]',
    ),
  ],
  roleSettings: _roleSettings,
);
