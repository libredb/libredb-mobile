/// The database a server-level connection runs in when the editor opens, as Studio's web picks it
/// (libredb-studio `src/hooks/use-connection-manager.ts`): [wanted], the one chosen in this session or else the one
/// remembered on the device, while the server still lists it, else the first [listed], or null when it lists none.
String? defaultCatalog({required List<String> listed, String? wanted}) {
  if (wanted != null && listed.contains(wanted)) return wanted;
  return listed.isEmpty ? null : listed.first;
}
