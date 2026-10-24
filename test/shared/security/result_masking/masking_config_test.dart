import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_config.dart';

// Pins the port of Studio's DEFAULT_MASKING_CONFIG (src/lib/data-masking.ts:34-153 at libredb-studio c9989a6b5),
// written out here a second time on purpose: a later sync with Studio changes this list, so it shows up as a visible
// diff.
void main() {
  test('the default patterns, their column patterns and mask types are those of Studio c9989a6b5', () {
    expect(
      [
        for (final p in defaultMaskingConfig.patterns)
          [p.id, p.name, p.columnPatterns, p.maskType, p.enabled, p.isBuiltin, p.customMask],
      ],
      [
        [
          'builtin-email',
          'Email',
          ['email', 'e_mail', 'user_email', 'customer_email', 'contact_email'],
          MaskType.email,
          true,
          true,
          null,
        ],
        [
          'builtin-password',
          'Password',
          ['password', 'passwd', 'pass', 'pwd', 'secret', 'user_password', 'hashed_password', 'password_hash', 'hash'],
          MaskType.full,
          true,
          true,
          null,
        ],
        [
          'builtin-ssn',
          'SSN',
          ['ssn', 'social_security', 'social_security_number', 'national_id', 'national_number'],
          MaskType.ssn,
          true,
          true,
          null,
        ],
        [
          'builtin-card',
          'Credit Card',
          ['credit_card', 'card_number', 'cc_number', 'card_num', 'pan', 'credit_card_number'],
          MaskType.card,
          true,
          true,
          null,
        ],
        [
          'builtin-phone',
          'Phone',
          ['phone', 'phone_number', 'mobile', 'cell', 'telephone', 'tel', 'contact_phone'],
          MaskType.phone,
          true,
          true,
          null,
        ],
        [
          'builtin-token',
          'Token/Key',
          [
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
          MaskType.partial,
          true,
          true,
          null,
        ],
        [
          'builtin-address',
          'Address',
          ['address', 'street', 'street_address', 'home_address', 'billing_address', 'shipping_address'],
          MaskType.full,
          true,
          true,
          null,
        ],
        [
          'builtin-ip',
          'IP Address',
          ['ip', 'ip_address', 'client_ip', 'remote_ip', 'source_ip'],
          MaskType.ip,
          true,
          true,
          null,
        ],
        [
          'builtin-financial',
          'Financial',
          ['salary', 'income', 'balance', 'amount', 'wage', 'compensation', 'net_pay', 'gross_pay', 'revenue'],
          MaskType.financial,
          true,
          true,
          null,
        ],
        [
          'builtin-birthdate',
          'Birthdate',
          ['birth', 'dob', 'date_of_birth', 'birthdate', 'birth_date', 'birthday'],
          MaskType.date,
          true,
          true,
          null,
        ],
      ],
    );
  });

  test('masking is on, and only the admin may toggle and reveal, as in Studio c9989a6b5', () {
    expect(defaultMaskingConfig.enabled, isTrue);
    final roles = defaultMaskingConfig.roleSettings;
    expect((roles.admin.canToggle, roles.admin.canReveal), (true, true));
    expect((roles.user.canToggle, roles.user.canReveal), (false, false));
  });

  test("the mask types are Studio's MaskType union", () {
    expect(MaskType.values.map((t) => t.name), [
      'email',
      'phone',
      'card',
      'ssn',
      'full',
      'partial',
      'ip',
      'date',
      'financial',
      'custom',
    ]);
  });
}
