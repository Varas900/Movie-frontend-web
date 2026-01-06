class ApiPermissionEntry {
  final String method;
  final String pathTemplate;
  final String? permission;
  final bool isPublic;

  const ApiPermissionEntry({
    required this.method,
    required this.pathTemplate,
    required this.permission,
    required this.isPublic,
  });
}
