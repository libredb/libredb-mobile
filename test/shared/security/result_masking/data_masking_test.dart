import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_functions.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_config.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/security/result_masking/sensitive_columns.dart';

import 'masking_configs.dart';

// Ports Studio's tests/unit/lib/data-masking.test.ts at libredb-studio c9989a6b5. The cases of the config persistence
// (`loadMaskingConfig`, `saveMaskingConfig`) and of the settings previews (`getPreviewMasked`) are not ported: the
// phone has neither, since it masks with the defaults only. The `partial`, `email` and `date` cases follow the
// corrected rules of libredb/libredb-studio#1915 and #1917, and say where they differ from Studio.

MaskingPattern _pattern(MaskType maskType, {String? customMask}) => MaskingPattern(
  id: 'test-pattern',
  name: 'Test',
  columnPatterns: const ['test'],
  maskType: maskType,
  customMask: customMask,
);

MaskingConfig _config(List<MaskingPattern> patterns) =>
    MaskingConfig(enabled: true, patterns: patterns, roleSettings: defaultMaskingConfig.roleSettings);

void main() {
  group('maskByType', () {
    test('masks email address', () {
      final result = maskByType('john.doe@example.com', _pattern(MaskType.email));
      expect(result, contains('@'));
      expect(result, startsWith('j'));
      expect(result, contains('*'));
      expect(result, isNot('john.doe@example.com'));
    });

    test('masks malformed email (no @)', () {
      expect(maskByType('notanemail', _pattern(MaskType.email)), '***@***.***');
    });

    test('masks phone number', () {
      final result = maskByType('+1-555-123-4567', _pattern(MaskType.phone));
      expect(result, endsWith('4567'));
      expect(result, contains('*'));
    });

    test('masks short phone number (less than 4 digits)', () {
      expect(maskByType('123', _pattern(MaskType.phone)), '***');
    });

    test('masks credit card number', () {
      expect(maskByType('4111111111111234', _pattern(MaskType.card)), '****-****-****-1234');
    });

    test('masks credit card with dashes', () {
      expect(maskByType('4111-1111-1111-5678', _pattern(MaskType.card)), '****-****-****-5678');
    });

    test('masks SSN', () {
      final result = maskByType('123-45-6789', _pattern(MaskType.ssn));
      expect(result, startsWith('***-**-'));
      expect(result, endsWith('6789'));
    });

    test('full mask replaces everything', () {
      expect(maskByType('some secret value', _pattern(MaskType.full)), '********');
    });

    // Studio shows `sk-p`, twelve stars and `z789` (#1915); the corrected rule shows two characters at each end of 20.
    test('partial mask preserves a few characters at each end of a long value and keeps its length', () {
      final result = maskByType('sk-proj-abc123xyz789', _pattern(MaskType.partial));
      expect(result, 'sk${'*' * 16}89');
      expect(result, hasLength(20));
    });

    test('partial mask fully masks short values (<=8 chars)', () {
      expect(maskByType('abcd1234', _pattern(MaskType.partial)), '********');
    });

    test('masks IP address', () {
      expect(maskByType('192.168.1.100', _pattern(MaskType.ip)), '192.***.***.100');
    });

    test('masks non-IPv4 address', () {
      expect(maskByType('::1', _pattern(MaskType.ip)), '***');
    });

    test('masks date', () {
      expect(maskByType('1990-05-15', _pattern(MaskType.date)), '****-**-15');
    });

    test('masks short date', () {
      expect(maskByType('05', _pattern(MaskType.date)), '****-**-**');
    });

    test('masks financial value', () {
      expect(maskByType('85000.00', _pattern(MaskType.financial)), '***,***.**');
    });

    test('custom mask returns custom string', () {
      expect(maskByType('anything', _pattern(MaskType.custom, customMask: '[REDACTED]')), '[REDACTED]');
    });

    test('custom mask with no customMask falls back to ***', () {
      expect(maskByType('anything', _pattern(MaskType.custom)), '***');
      expect(maskByType('anything', _pattern(MaskType.custom, customMask: '')), '***');
    });
  });

  group('the corrected mask functions (libredb/libredb-studio#1915 and #1917)', () {
    test('partial shows 2 of the 9 characters of abcdefghi', () {
      expect(maskByType('abcdefghi', _pattern(MaskType.partial)), 'a*******i');
    });

    test('partial keeps the length and shows at most a quarter of the value', () {
      for (var n = 1; n <= 64; n++) {
        final value = String.fromCharCodes(List.generate(n, (i) => 0x41 + i % 26));
        final masked = maskByType(value, _pattern(MaskType.partial));
        expect(masked, hasLength(n), reason: 'length $n');
        final shown = masked.split('').where((c) => c != '*').length;
        expect(shown, lessThanOrEqualTo(n ~/ 4), reason: 'length $n');
      }
      expect(maskByType('abcdefghij', _pattern(MaskType.partial)), 'a********j');
      expect(maskByType('a' * 31, _pattern(MaskType.partial)), 'aaa${'*' * 25}aaa');
      expect(maskByType('0123456789abcdef0123456789abcdef', _pattern(MaskType.partial)), '0123${'*' * 24}cdef');
    });

    test('an email with an empty local part or domain gives the generic mask, never undefined', () {
      expect(maskByType('@example.com', _pattern(MaskType.email)), '***@***.***');
      expect(maskByType('bob@', _pattern(MaskType.email)), '***@***.***');
      expect(maskByType('@', _pattern(MaskType.email)), '***@***.***');
    });

    test('a timestamp under the date rule shows no part of itself', () {
      expect(maskByType('1990-05-17T00:00:00.000Z', _pattern(MaskType.date)), '****-**-**');
      expect(maskByType('1990-05-17 00:00:00+00', _pattern(MaskType.date)), '****-**-**');
      expect(maskByType('17.05.1990', _pattern(MaskType.date)), '****-**-**');
    });

    test('a bare calendar date keeps its day, as Studio does', () {
      expect(maskByType('1990-05-17', _pattern(MaskType.date)), '****-**-17');
    });
  });

  group('maskValueByPattern', () {
    test('returns NULL for null value', () {
      expect(maskValueByPattern(null, _pattern(MaskType.email)), 'NULL');
    });

    test('masks string value using pattern', () {
      final result = maskValueByPattern('john@example.com', _pattern(MaskType.email));
      expect(result, contains('*'));
      expect(result, isNot('john@example.com'));
    });

    test('converts number to string before masking', () {
      expect(maskValueByPattern(12345, _pattern(MaskType.full)), '********');
    });
  });

  group('detectSensitiveColumns', () {
    test('detects matching columns based on enabled patterns', () {
      final result = detectSensitiveColumns(['id', 'name', 'email', 'phone'], maskingConfigEnabled);
      expect(result, hasLength(2));
      expect(result.containsKey('email'), isTrue);
      expect(result.containsKey('phone'), isTrue);
      expect(result.containsKey('id'), isFalse);
    });

    test('returns empty map when all patterns are disabled', () {
      expect(detectSensitiveColumns(['email', 'ssn', 'phone'], maskingConfigAllDisabledPatterns), isEmpty);
    });

    test('matches case-insensitively', () {
      final result = detectSensitiveColumns(['EMAIL', 'Phone'], maskingConfigEnabled);
      expect(result.containsKey('EMAIL'), isTrue);
      expect(result.containsKey('Phone'), isTrue);
    });

    test('detects custom regex patterns', () {
      final result = detectSensitiveColumns(['secret_field', 'internal_data', 'public_field'], maskingConfigWithCustom);
      expect(result.containsKey('secret_field'), isTrue);
      expect(result.containsKey('internal_data'), isTrue);
      expect(result.containsKey('public_field'), isFalse);
    });

    test('a repeated sensitive column the result numbered is masked like the column it repeats', () {
      final result = detectSensitiveColumns([
        'email',
        'email (2)',
        'ssn',
        'ssn (3)',
        'credit_card (2)',
      ], defaultMaskingConfig);
      expect(result['email (2)'], same(result['email']));
      expect(result['ssn (3)'], same(result['ssn']));
      expect(result.containsKey('credit_card (2)'), isTrue);
    });

    test('a numbered name is masked by its base even alone, and after a second numbering', () {
      expect(detectSensitiveColumns(['phone (2)'], maskingConfigEnabled).containsKey('phone (2)'), isTrue);
      expect(detectSensitiveColumns(['email (2) (2)'], maskingConfigEnabled).containsKey('email (2) (2)'), isTrue);
    });

    // Studio pins this against `uniqueFieldNames`, which numbers a repeat `name (2)`, `name (3)`; the phone reads the
    // names Studio already numbered.
    test('every repeat Studio numbers is masked like the column it repeats', () {
      final result = detectSensitiveColumns(['email', 'id', 'email (2)', 'email (3)', 'id (2)'], defaultMaskingConfig);
      expect(result.keys, ['email', 'email (2)', 'email (3)']);
    });

    test('only the numbered form reads back to its base; any other name keeps its own rule', () {
      final config = _config([
        const MaskingPattern(id: 'base', name: 'Test', columnPatterns: ['email'], maskType: MaskType.email),
        const MaskingPattern(id: 'own', name: 'Test', columnPatterns: [r'email \(work\)'], maskType: MaskType.full),
      ]);
      final result = detectSensitiveColumns([
        'id',
        'id (2)',
        '(No column name)',
        'email (2)',
        'email (work)',
        'email (2)x',
      ], config);
      expect([for (final e in result.entries) (e.key, e.value.id)], [('email (2)', 'base'), ('email (work)', 'own')]);
    });

    test('returns empty map for no fields', () {
      expect(detectSensitiveColumns([], maskingConfigEnabled), isEmpty);
    });

    test('only first matching pattern wins for a field', () {
      final config = _config([
        const MaskingPattern(id: 'p1', name: 'Test', columnPatterns: ['email'], maskType: MaskType.email),
        const MaskingPattern(id: 'p2', name: 'Test', columnPatterns: ['email'], maskType: MaskType.full),
      ]);
      expect(detectSensitiveColumns(['email'], config)['email']!.maskType, MaskType.email);
    });

    test('invalid regex column pattern falls back to case-insensitive equality', () {
      final config = _config([
        const MaskingPattern(id: 'broken-regex', name: 'Test', columnPatterns: ['se(cret'], maskType: MaskType.full),
      ]);
      final result = detectSensitiveColumns(['SE(CRET', 'other'], config);
      expect(result.containsKey('SE(CRET'), isTrue);
      expect(result.containsKey('other'), isFalse);
    });
  });

  group('numberedRepeatBase', () {
    test('reads the base of a numbered name once, and null for any other name', () {
      expect(numberedRepeatBase('email (2)'), 'email');
      expect(numberedRepeatBase('a (2) (2)'), 'a (2)');
      expect(numberedRepeatBase('email (12)'), 'email');
      expect(numberedRepeatBase('email (work)'), isNull);
      expect(numberedRepeatBase('email (2)x'), isNull);
      expect(numberedRepeatBase('email(2)'), isNull);
    });
  });

  group('shouldMask', () {
    test('admin role with masking enabled returns true', () {
      expect(shouldMask(MaskingRoleKind.admin, maskingConfigEnabled), isTrue);
    });

    test('admin role with masking disabled returns false', () {
      expect(shouldMask(MaskingRoleKind.admin, maskingConfigDisabled), isFalse);
    });

    test('user role with canToggle=false always returns true', () {
      expect(shouldMask(MaskingRoleKind.user, maskingConfigEnabled), isTrue);
      expect(shouldMask(MaskingRoleKind.user, maskingConfigDisabled), isTrue);
    });

    test('user role with canToggle=true respects config.enabled', () {
      expect(shouldMask(MaskingRoleKind.user, maskingConfigUserCanToggle), isTrue);
      final disabledTogglable = MaskingConfig(
        enabled: false,
        patterns: maskingConfigUserCanToggle.patterns,
        roleSettings: maskingConfigUserCanToggle.roleSettings,
      );
      expect(shouldMask(MaskingRoleKind.user, disabledTogglable), isFalse);
    });

    test('a role not yet known is treated as user', () {
      expect(shouldMask(MaskingRoleKind.of(null), maskingConfigEnabled), isTrue);
    });
  });

  group('maskingInForce', () {
    test("is off whenever the role and config say no masking, whatever the shell's switch says", () {
      expect(maskingInForce(MaskingRoleKind.admin, maskingConfigDisabled, true), isFalse);
      expect(maskingInForce(MaskingRoleKind.admin, maskingConfigDisabled, null), isFalse);
    });

    test('follows the shell switch when the role and config allow masking', () {
      expect(maskingInForce(MaskingRoleKind.admin, maskingConfigEnabled, true), isTrue);
      expect(maskingInForce(MaskingRoleKind.admin, maskingConfigEnabled, false), isFalse);
    });

    test("falls back to the config's own flag when the shell passes no switch", () {
      expect(maskingInForce(MaskingRoleKind.user, maskingConfigEnabled, null), isTrue);
      final disabledTogglable = MaskingConfig(
        enabled: false,
        patterns: maskingConfigUserCanToggle.patterns,
        roleSettings: maskingConfigUserCanToggle.roleSettings,
      );
      expect(maskingInForce(MaskingRoleKind.user, disabledTogglable, null), isFalse);
    });
  });

  group('canToggleMasking', () {
    test('admin can toggle by default', () {
      expect(canToggleMasking(MaskingRoleKind.admin, maskingConfigEnabled), isTrue);
    });

    test('user cannot toggle by default', () {
      expect(canToggleMasking(MaskingRoleKind.user, maskingConfigEnabled), isFalse);
    });

    test('user can toggle when config allows', () {
      expect(canToggleMasking(MaskingRoleKind.user, maskingConfigUserCanToggle), isTrue);
    });

    test('a role not yet known is treated as user', () {
      expect(canToggleMasking(MaskingRoleKind.of(null), maskingConfigEnabled), isFalse);
    });
  });

  group('canReveal', () {
    test('admin can reveal by default', () {
      expect(canReveal(MaskingRoleKind.admin, maskingConfigEnabled), isTrue);
    });

    test('user cannot reveal by default', () {
      expect(canReveal(MaskingRoleKind.user, maskingConfigEnabled), isFalse);
    });

    test('user can reveal when config allows', () {
      expect(canReveal(MaskingRoleKind.user, maskingConfigUserCanToggle), isTrue);
    });

    test('a role not yet known is treated as user', () {
      expect(canReveal(MaskingRoleKind.of(null), maskingConfigEnabled), isFalse);
    });
  });

  group('applyMaskingToRows', () {
    final rows = <Map<String, Object?>>[
      {'id': 1, 'email': 'alice@example.com', 'name': 'Alice'},
      {'id': 2, 'email': 'bob@example.com', 'name': 'Bob'},
    ];

    test('returns original rows when sensitiveColumns is empty', () {
      expect(applyMaskingToRows(rows, ['id', 'email', 'name'], const {}), same(rows));
    });

    test('masks sensitive columns', () {
      final sensitive = detectSensitiveColumns(['id', 'email', 'name'], maskingConfigEnabled);
      final result = applyMaskingToRows(rows, ['id', 'email', 'name'], sensitive);
      expect(result[0]['id'], 1);
      expect(result[0]['name'], 'Alice');
      expect(result[0]['email'], isNot('alice@example.com'));
      expect(result[0]['email'], contains('*'));
    });

    test('preserves null values (does not mask)', () {
      final sensitive = detectSensitiveColumns(['id', 'email', 'name'], maskingConfigEnabled);
      final result = applyMaskingToRows(
        [
          {'id': 1, 'email': null, 'name': 'Alice'},
        ],
        ['id', 'email', 'name'],
        sensitive,
      );
      expect(result[0].containsKey('email'), isTrue);
      expect(result[0]['email'], isNull);
    });

    test('leaves an absent value absent', () {
      final sensitive = detectSensitiveColumns(['id', 'email'], maskingConfigEnabled);
      final result = applyMaskingToRows(
        [
          {'id': 1},
        ],
        ['id', 'email'],
        sensitive,
      );
      expect(result[0], {'id': 1});
    });

    test('does not mutate original rows', () {
      final original = <Map<String, Object?>>[
        {'id': 1, 'email': 'test@test.com'},
      ];
      final sensitive = detectSensitiveColumns(['id', 'email'], maskingConfigEnabled);
      applyMaskingToRows(original, ['id', 'email'], sensitive);
      expect(original[0]['email'], 'test@test.com');
    });
  });

  // Ports Studio's tests/unit/lib/data-masking-address.test.ts at c9989a6b5.
  group('the built-in address rule', () {
    MaskingPattern? rule(String field) => detectSensitiveColumns([field], defaultMaskingConfig)[field];

    test('fires on a column named address, and the value does not survive it', () {
      final pattern = rule('address');
      expect(pattern?.id, 'builtin-address');
      final masked = maskValueByPattern('221B Baker Street', pattern!);
      expect(masked, isNot('221B Baker Street'));
      expect(masked, isNot(contains('Baker')));
    });

    for (final field in [
      'address',
      'street',
      'street_address',
      'home_address',
      'billing_address',
      'shipping_address',
    ]) {
      test('covers $field', () {
        expect(rule(field)?.id, 'builtin-address');
      });
    }

    test('the patterns are anchored, so a column that merely ends in address is untouched', () {
      for (final field in ['register_address', 'mac_address', 'addressing', 'address_of_record']) {
        expect((field, rule(field)?.id), (field, null));
      }
    });

    test('a repeated column is masked like the column it repeats', () {
      expect(rule('address (2)')?.id, 'builtin-address');
    });

    test('matching is on the name alone, with no type and no engine in reach', () {
      final byName = detectSensitiveColumns(['address'], defaultMaskingConfig);
      expect(byName['address']?.id, 'builtin-address');
      expect(byName, hasLength(1));
    });
  });

  // Ports Studio's tests/unit/components/results-grid-masking-exemption.test.ts at c9989a6b5. Studio reads the fields
  // from a read through its Modbus provider; the phone has no Modbus device, so the fields are the two field lists of
  // `src/lib/db/providers/industrial/modbus/read.ts` (`POINT_FIELDS`, `RANGE_FIELDS`) and the declaration is the one of
  // `modbus/constants.ts`.
  group('a Modbus address column is left open, and says why', () {
    const pointFields = ['point', 'unit', 'table', 'address', 'type', 'raw', 'value', 'unit_of_measure'];
    const rangeFields = ['unit', 'table', 'address', 'raw', 'value'];
    const declared = MaskingExemptColumn(
      column: r'^address$',
      reason: 'The PDU register number this row answered for, not a postal address, so it is shown as it was read.',
    );

    for (final (name, fields) in [('a range read', rangeFields), ('a named-point read', pointFields)]) {
      test('$name answers an address column, and it is not masked', () {
        final split = splitMaskedColumns(fields, defaultMaskingConfig, declared);
        expect((split.masked.containsKey('address'), split.exempt.containsKey('address')), (false, true));
        expect(split.exempt['address'], declared.reason);
      });
    }

    test('the rules themselves are untouched: with no declaration the same column is still masked', () {
      final split = splitMaskedColumns(rangeFields, defaultMaskingConfig, null);
      expect((split.masked.containsKey('address'), split.exempt.length), (true, 0));
    });

    test('it exempts, it never adds: a column the engine did not name stays masked', () {
      final split = splitMaskedColumns([...rangeFields, 'email'], defaultMaskingConfig, declared);
      expect((split.masked.containsKey('email'), split.exempt.containsKey('email')), (true, false));
    });

    test('the exemption is unanchored and case-sensitive, as Studio compiles it', () {
      const loose = MaskingExemptColumn(column: 'address', reason: 'r');
      final split = splitMaskedColumns(['address', 'ip_address', 'Address'], defaultMaskingConfig, loose);
      expect(split.exempt.keys, ['address', 'ip_address']);
      expect(split.masked.keys, ['Address']);
    });
  });
}
