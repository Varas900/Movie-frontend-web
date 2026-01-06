import 'api_permission_entry.dart';
import 'api_permission_map.dart';

class MatchedPermission {
  final ApiPermissionEntry entry;
  final String path;

  const MatchedPermission({required this.entry, required this.path});
}

RegExp _templateToRegex(String template) {
  final placeholder = RegExp(r'\{[^}]+\}');
  final parts = template.split(placeholder).map(RegExp.escape).toList(growable: false);
  final placeholderCount = placeholder.allMatches(template).length;

  var pattern = '';
  for (var i = 0; i < parts.length; i++) {
    pattern += parts[i];
    if (i < placeholderCount) pattern += r'[^/]+';
  }

  return RegExp('^$pattern\$');
}

class _CompiledEntry {
  final ApiPermissionEntry entry;
  final RegExp regex;

  const _CompiledEntry(this.entry, this.regex);
}

final List<_CompiledEntry> _compiled = apiPermissions
    .map((e) => _CompiledEntry(e, _templateToRegex(e.pathTemplate)))
    .toList(growable: false);

/// Find the permission entry matching [method] and [endpoint].
///
/// Policy: returns null if no match (loose).
MatchedPermission? matchApiPermission(String method, String endpoint) {
  final httpMethod = method.toUpperCase();
  final path = endpoint.split('?').first;

  for (final c in _compiled) {
    if (c.entry.method.toUpperCase() != httpMethod) continue;
    if (c.regex.hasMatch(path)) {
      return MatchedPermission(entry: c.entry, path: path);
    }
  }

  return null;
}
