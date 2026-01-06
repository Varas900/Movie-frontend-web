import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'storage_service.dart';
import '../services/http_client_factory.dart';
import '../utils/app_constants.dart';

class UserService {
  final http.Client _client;

  UserService({http.Client? client}) : _client = client ?? _defaultClient();

  static http.Client _defaultClient() {
    return createHttpClient(withCredentials: true);
  }

  Map<String, String> _authHeaders({bool includeJson = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (includeJson) 'Content-Type': 'application/json',
    };
    final token = StorageService.getUserToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body['data'] ?? body['Data'] ?? body['result'] ?? body;
    }
    return body;
  }

  Map<String, dynamic>? _safeDecode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return null;
    }
  }

  String _extractMessage(Map<String, dynamic>? body, String fallback) {
    if (body == null) return fallback;
    final keys = ['message', 'Message', 'error', 'title', 'detail'];
    for (final k in keys) {
      final v = body[k];
      if (v is String && v.isNotEmpty) return v;
    }
    final errs = body['errors'];
    if (errs is Map) {
      for (final entry in errs.entries) {
        final val = entry.value;
        if (val is List && val.isNotEmpty && val.first is String) {
          return val.first as String;
        }
      }
    }
    return fallback;
  }

  String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<Map<String, dynamic>> getMe() async {
    final uri = Uri.parse('${AppConstants.baseApiUrl}/user/me');
    final res = await _client.get(uri, headers: _authHeaders());

    final decoded = _safeDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractMessage(decoded, 'Get /user/me failed (HTTP ${res.statusCode})'));
    }

    final inner = decoded == null ? null : _unwrap(decoded);
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    throw Exception('Unexpected /user/me response');
  }

  Future<Map<String, dynamic>> getUserSlimById(int userId) async {
    // Backend route is literally: /user/GetUserSlimById{userID}
    // (no slash between action name and id).
    final uri = Uri.parse('${AppConstants.baseApiUrl}/user/GetUserSlimById$userId');
    final res = await _client.get(uri, headers: _authHeaders(includeJson: false));

    final decoded = _safeDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractMessage(decoded, 'Get user slim failed (HTTP ${res.statusCode})'),
      );
    }

    final inner = decoded == null ? null : _unwrap(decoded);
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    throw Exception('Unexpected user slim response');
  }

  Future<void> updateUsername({required int userId, required String newUsername}) async {
    final uri = Uri.parse('${AppConstants.baseApiUrl}/user/update/username')
        .replace(queryParameters: <String, String>{
      'userId': userId.toString(),
      'newUsername': newUsername,
    });

    final res = await _client.put(uri, headers: _authHeaders());
    final decoded = _safeDecode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractMessage(decoded, 'Update username failed (HTTP ${res.statusCode})'));
    }
  }

  Future<void> updateProfileMultipart({
    required int userId,
    required String newUserName,
    required String firstName,
    required String lastName,
    String? gender,
    DateTime? dateOfBirth,
    XFile? avatar,
  }) async {
    final uri = Uri.parse('${AppConstants.baseApiUrl}/user/update/profile');
    final req = http.MultipartRequest('PUT', uri);

    req.headers.addAll(_authHeaders(includeJson: false));

    req.fields['userID'] = userId.toString();
    req.fields['newUserName'] = newUserName;
    req.fields['firstName'] = firstName;
    req.fields['lastName'] = lastName;
    if (gender != null) req.fields['gender'] = gender;
    // Swagger marks this as string($date-time), so send ISO-8601.
    if (dateOfBirth != null) req.fields['dateOfBirth'] = dateOfBirth.toIso8601String();

    if (avatar != null) {
      final bytes = await avatar.readAsBytes();
      final filename = (avatar.name.isNotEmpty) ? avatar.name : 'avatar.jpg';
      req.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: filename,
        ),
      );
    }

    final streamed = await _client.send(req);
    final bodyText = await streamed.stream.bytesToString();
    final decoded = bodyText.isEmpty ? null : _safeDecode(bodyText);

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception(
        _extractMessage(decoded, 'Update profile failed (HTTP ${streamed.statusCode})'),
      );
    }
  }

  Future<void> deleteAccount({required int userId}) async {
    final uri = Uri.parse('${AppConstants.baseApiUrl}/user/deleteUser')
        .replace(queryParameters: <String, String>{
      'userId': userId.toString(),
    });

    final res = await _client.delete(uri, headers: _authHeaders());
    final decoded = _safeDecode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractMessage(decoded, 'Delete account failed (HTTP ${res.statusCode})'));
    }
  }
}
