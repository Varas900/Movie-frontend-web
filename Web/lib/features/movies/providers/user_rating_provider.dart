import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/user_rating_model.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/http_client_factory.dart';

class UserRatingRepository {
  final http.Client _client;

  UserRatingRepository({http.Client? client}) : _client = client ?? createHttpClient(withCredentials: true);

  Map<String, String> _authHeaders() {
    final token = StorageService.getUserToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
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

  Future<List<UserRating>> fetchByMovieId(int movieId) async {
    final token = StorageService.getUserToken();
    if (token == null || token.trim().isEmpty) return [];

    final uri = Uri.parse('${AppConstants.baseApiUrl}/api/UserRating/GetAllUserRatingsByMovieId/$movieId');
    final res = await http.get(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return [];

    final body = jsonDecode(res.body);
    final data = _unwrap(body);
    final list = (data is List) ? data : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => UserRating.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<UserRating>> fetchByUserId(int userId) async {
    final token = StorageService.getUserToken();
    if (token == null || token.trim().isEmpty) return [];

    final uri = Uri.parse('${AppConstants.baseApiUrl}/api/UserRating/GetAllUserRatingsByUserId/$userId');
    final res = await http.get(uri, headers: _authHeaders());
    if (res.statusCode == 404) return [];
    if (res.statusCode < 200 || res.statusCode >= 300) return [];

    final body = jsonDecode(res.body);
    final data = _unwrap(body);
    final list = (data is List) ? data : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => UserRating.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<UserRating?> fetchMyRatingForMovie({
    required int movieId,
    required int userId,
  }) async {
    final ratings = await fetchByUserId(userId);
    try {
      return ratings.firstWhere((r) => r.movieId == movieId);
    } catch (_) {
      return null;
    }
  }

  Future<UserRating?> upsertRating({
    required int movieId,
    required int userId,
    required int stars,
    int? userRatingId,
  }) async {
    final token = StorageService.getUserToken();
    if (token == null || token.trim().isEmpty) return null;

    if (userRatingId != null && userRatingId > 0) {
      final uri = Uri.parse('${AppConstants.baseApiUrl}/api/UserRating/UpdateUserRating');
      final res = await _client.put(
        uri,
        headers: _authHeaders(),
        body: jsonEncode({
          'userRatingID': userRatingId,
          'userID': userId,
          'movieID': movieId,
          'rating': stars,
        }),
      );
		if (res.statusCode == 401) throw Exception('HTTP_401');
		if (res.statusCode == 403) throw Exception('HTTP_403');
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body);
      final data = _unwrap(body);
      return (data is Map<String, dynamic>) ? UserRating.fromJson(data) : null;
    }

    final uri = Uri.parse('${AppConstants.baseApiUrl}/api/UserRating/CreateUserRating');
    final res = await _client.post(
      uri,
      headers: _authHeaders(),
      body: jsonEncode({
        'userID': userId,
        'movieID': movieId,
        'rating': stars,
      }),
    );
	if (res.statusCode == 401) throw Exception('HTTP_401');
	if (res.statusCode == 403) throw Exception('HTTP_403');
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    final data = _unwrap(body);
    return (data is Map<String, dynamic>) ? UserRating.fromJson(data) : null;
  }
}

final userRatingRepositoryProvider = Provider<UserRatingRepository>((ref) => UserRatingRepository());

final movieUserRatingsProvider = FutureProvider.family<List<UserRating>, int>((ref, movieId) async {
  final repo = ref.read(userRatingRepositoryProvider);
  return repo.fetchByMovieId(movieId);
});

final myUserRatingProvider = FutureProvider.family<UserRating?, int>((ref, movieId) async {
  final user = ref.watch(currentUserProvider);
  final userId = user?.userId;
  if (userId == null || userId <= 0) return null;

  final repo = ref.read(userRatingRepositoryProvider);
  return repo.fetchMyRatingForMovie(movieId: movieId, userId: userId);
});
