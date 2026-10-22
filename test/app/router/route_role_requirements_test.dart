import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/router/route_role_requirements.dart';
import 'package:libredb_mobile/core/security/safe_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requiredRolesFor', () {
    test('no route of the app is restricted', () {
      expect(routeRoleRequirements, isEmpty);
      for (final path in [
        ApplicationRoutesConstants.root,
        ApplicationRoutesConstants.connectionList,
        ApplicationRoutesConstants.settings,
        '/admin',
      ]) {
        expect(requiredRolesFor(path), isEmpty, reason: path);
      }
    });

    const requirements = <String, Set<String>>{
      '/admin': {'admin'},
      '/admin/audit': {'auditor'},
    };

    test('returns the roles of a registered prefix', () {
      expect(requiredRolesFor('/admin', requirements: requirements), {'admin'});
    });

    test('inherits restriction via longest-prefix: /admin/users/1 also requires admin', () {
      expect(requiredRolesFor('/admin/users/1', requirements: requirements), {'admin'});
      expect(requiredRolesFor('/admin/audit/today', requirements: requirements), {'auditor'});
    });

    test('returns empty for an unrelated sibling path', () {
      expect(requiredRolesFor('/administrator', requirements: requirements), isEmpty);
    });
  });

  group('hasAnyRequiredRole', () {
    test('empty requirement → always allowed', () {
      expect(hasAnyRequiredRole(<String>{}, <String>{}), isTrue);
      expect(hasAnyRequiredRole({'ROLE_USER'}, <String>{}), isTrue);
    });

    test('user with required role → allowed', () {
      expect(hasAnyRequiredRole({'ROLE_ADMIN', 'ROLE_USER'}, {'ROLE_ADMIN'}), isTrue);
    });

    test('user with one of the OR-set roles → allowed', () {
      expect(hasAnyRequiredRole({'ROLE_REPORTER'}, {'ROLE_ADMIN', 'ROLE_REPORTER'}), isTrue);
    });

    test('user with no matching role → denied', () {
      expect(hasAnyRequiredRole({'ROLE_USER'}, {'ROLE_ADMIN'}), isFalse);
    });

    test('user with empty role set against non-empty requirement → denied', () {
      expect(hasAnyRequiredRole(<String>{}, {'ROLE_ADMIN'}), isFalse);
    });
  });

  group('safeRedirectTarget (open-redirect guard)', () {
    test('local path → passthrough', () {
      expect(safeRedirectTarget('/user/42/edit', fallback: '/'), '/user/42/edit');
    });

    test('local path with query → passthrough', () {
      expect(safeRedirectTarget('/admin?tab=1', fallback: '/'), '/admin?tab=1');
    });

    test('null or empty → fallback', () {
      expect(safeRedirectTarget(null, fallback: '/'), '/');
      expect(safeRedirectTarget('', fallback: '/'), '/');
    });

    test('absolute URL → fallback (off-origin)', () {
      expect(safeRedirectTarget('https://evil.example.com/steal', fallback: '/'), '/');
      expect(safeRedirectTarget('http://evil.example.com', fallback: '/'), '/');
    });

    test('protocol-relative path → fallback', () {
      expect(safeRedirectTarget('//evil.example.com/steal', fallback: '/'), '/');
    });

    test('backslash-prefixed path → fallback', () {
      expect(safeRedirectTarget(r'/\evil.example.com', fallback: '/'), '/');
    });

    test('path with no leading slash → fallback', () {
      expect(safeRedirectTarget('user/42', fallback: '/'), '/');
      expect(safeRedirectTarget('evil.example.com', fallback: '/'), '/');
    });

    test('data: scheme attempt → fallback', () {
      expect(safeRedirectTarget('data:text/html,<script>', fallback: '/'), '/');
    });
  });
}
