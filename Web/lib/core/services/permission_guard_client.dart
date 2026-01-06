import 'package:http/http.dart' as http;

import '../permissions/permission_denied_exception.dart';
import '../permissions/permission_route_matcher.dart';
import '../services/storage_service.dart';

/// HTTP client wrapper that performs a client-side permission check (UX) before
/// sending non-GET requests.
///
/// Backend remains the source of truth. This is only to avoid calling endpoints
/// that the current user plan clearly doesn't allow, and to surface the existing
/// HTTP_403 prompt flow.
class PermissionGuardClient extends http.BaseClient {
  final http.Client _inner;

  PermissionGuardClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method.toUpperCase();
    final path = request.url.path;

    final matched = matchApiPermission(method, path);
    if (matched != null) {
      final entry = matched.entry;

      // Match mobile behavior: only pre-block non-GET.
      if (method != 'GET' && !entry.isPublic && entry.permission != null) {
        // Avoid showing "plan required" when user is actually logged out.
        final token = StorageService.getUserToken();
        final hasToken = token != null && token.trim().isNotEmpty;
        if (hasToken) {
          final perms = StorageService.getPermissions();
          final hasPermission = perms.contains(entry.permission);
          if (!hasPermission) {
            throw PermissionDeniedException(
              requiredPermission: entry.permission!,
              method: method,
              path: matched.path,
            );
          }
        }
      }
    }

    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
