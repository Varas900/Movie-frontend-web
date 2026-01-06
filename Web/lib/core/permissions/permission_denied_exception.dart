class PermissionDeniedException implements Exception {
  final String requiredPermission;
  final String method;
  final String path;

  const PermissionDeniedException({
    required this.requiredPermission,
    required this.method,
    required this.path,
  });

  @override
  String toString() {
    // Keep HTTP_403 marker so existing authz_prompt logic can show "Plan required".
    return 'HTTP_403 Permission denied: $requiredPermission ($method $path)';
  }
}
