import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

import 'permission_guard_client.dart';

http.Client createHttpClient({bool withCredentials = true}) {
  if (kIsWeb) {
    final inner = BrowserClient()..withCredentials = withCredentials;
    return PermissionGuardClient(inner);
  }
  return PermissionGuardClient(http.Client());
}
