import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/saved_movie_model.dart';
import '../services/http_client_factory.dart';
import '../services/storage_service.dart';
import '../utils/app_constants.dart';

class SavedMovieService {
  final http.Client _client;

  SavedMovieService({http.Client? client}) : _client = client ?? _defaultClient();

  static http.Client _defaultClient() {
    // Keep withCredentials for cookie-based auth, and wrap with permission guard.
    return createHttpClient(withCredentials: true);
  }

  Map<String, String> _authHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
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

  Future<List<SavedMovie>> getSavedMoviesByUserId(int userId) async {
    final uri = Uri.parse(
      '${AppConstants.baseApiUrl}/api/SavedMovie/GetSavedMoviesByUserID/user/$userId',
    );

    final res = await _client.get(uri, headers: _authHeaders());
    if (res.statusCode == 401) throw Exception('HTTP_401');
    if (res.statusCode == 403) throw Exception('HTTP_403');
    if (res.statusCode != 200) {
      throw Exception('GetSavedMoviesByUserID HTTP ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    final data = _unwrap(decoded);
    if (data is! List) return const [];

    final out = <SavedMovie>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        out.add(SavedMovie.fromJson(item));
      } else if (item is Map) {
        out.add(SavedMovie.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return out;
  }

  Future<SavedMovie?> createSavedMovie({required int userId, required int movieId}) async {
    final uri = Uri.parse('${AppConstants.baseApiUrl}/api/SavedMovie/CreateSavedMovie');
    final res = await _client.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode({'userID': userId, 'movieID': movieId}),
    );

    if (res.statusCode == 401) throw Exception('HTTP_401');
    if (res.statusCode == 403) throw Exception('HTTP_403');

    if (res.statusCode == 400) {
      // Often "already saved".
      return null;
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('CreateSavedMovie HTTP ${res.statusCode}');
    }

    try {
      final decoded = jsonDecode(res.body);
      final data = _unwrap(decoded);
      if (data is Map<String, dynamic>) return SavedMovie.fromJson(data);
      if (data is Map) return SavedMovie.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      // ignore parse issues
    }

    return null;
  }

  Future<void> deleteSavedMovie(int savedMovieId) async {
    final uri = Uri.parse(
      '${AppConstants.baseApiUrl}/api/SavedMovie/DeleteSavedMovie/$savedMovieId',
    );
    final res = await _client.delete(uri, headers: _authHeaders());

    if (res.statusCode == 404) return;
	if (res.statusCode == 401) throw Exception('HTTP_401');
	if (res.statusCode == 403) throw Exception('HTTP_403');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('DeleteSavedMovie HTTP ${res.statusCode}');
    }
  }
}
