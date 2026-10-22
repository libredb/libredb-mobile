/// Central audit point for per-route role requirements.
///
/// Each entry maps a route prefix to the **OR** set of roles permitted
/// to reach it — a user authorized if they hold at least one of the
/// listed roles. ALL-semantics is rarely needed and would be an
/// awkward bolt-on; revisit only when a real call site demands it.
///
/// Maintained alongside `ApplicationRoutesConstants` so policy review
/// is a single grep. Route guards are belt-and-braces — UI also hides
/// admin entries — but you cannot rely on UI hiding alone (URL
/// guesses and deep links bypass it).
///
/// Prefix-keyed lookup. The router redirect picks the longest matching
/// prefix so a sub-path inherits its parent's rule without each
/// sub-path needing its own entry. No route is restricted yet.
const Map<String, Set<String>> routeRoleRequirements = <String, Set<String>>{};

/// Returns the required roles for [path] in [requirements], or an empty
/// set when the route is unrestricted. Matching uses longest-prefix to
/// avoid the per-sub-route maintenance burden.
Set<String> requiredRolesFor(String path, {Map<String, Set<String>> requirements = routeRoleRequirements}) {
  String? bestKey;
  for (final key in requirements.keys) {
    if ((path == key || path.startsWith('$key/')) && (bestKey == null || key.length > bestKey.length)) {
      bestKey = key;
    }
  }
  return bestKey == null ? const <String>{} : requirements[bestKey]!;
}

/// True when [userRoles] intersects [required]. Empty `required` ⇒ open
/// access (no roles needed).
bool hasAnyRequiredRole(Set<String> userRoles, Set<String> required) {
  if (required.isEmpty) return true;
  for (final r in required) {
    if (userRoles.contains(r)) return true;
  }
  return false;
}
