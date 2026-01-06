import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/movie_model.dart';
import '../models/review_model.dart';
import '../services/storage_service.dart';
import '../utils/app_constants.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _authHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
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

  Map<String, dynamic> _normalizeMovieJson(Map<String, dynamic> json) {
    if (!json.containsKey('movieID') && json.containsKey('movieId')) {
      return {
        ...json,
        'movieID': json['movieId'],
      };
    }
    return json;
  }

  Movie _parseMovie(String responseBody) {
    final decoded = jsonDecode(responseBody);
    final data = _unwrap(decoded);
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected movie response shape');
    }
    return Movie.fromJson(_normalizeMovieJson(data));
  }

  /// Movie details:
  /// - Prefer watchNow (authenticated) for richer data.
  /// - If unauthorized (401/403), fall back to the anonymous GetMovieById.
  Future<Movie> getMovieDetails(int movieId) async {
    final watchNowUri = Uri.parse(
      '${AppConstants.baseApiUrl}/api/Movie/GetWatchNowMovieByID/watchNow/$movieId',
    );

    final watchNowRes = await _client.get(watchNowUri, headers: _authHeaders());
    if (watchNowRes.statusCode == 200) {
      return _parseMovie(watchNowRes.body);
    }

    if (watchNowRes.statusCode != 401 && watchNowRes.statusCode != 403) {
      throw Exception(
        'watchNow HTTP ${watchNowRes.statusCode}: ${watchNowRes.body}',
      );
    }

    final basicUri = Uri.parse(
      '${AppConstants.baseApiUrl}/api/Movie/GetMovieById/$movieId',
    );
    final basicRes = await _client.get(basicUri, headers: _authHeaders());
    if (basicRes.statusCode == 200) {
      return _parseMovie(basicRes.body);
    }

    throw Exception('GetMovieById HTTP ${basicRes.statusCode}: ${basicRes.body}');
  }

  // The rest of the API surface used by providers/widgets.
  // These return safe defaults for now.

  Future<List<Movie>> getMoviesByCategory(String category) async => const [];

  Future<List<Movie>> searchMovies(String query) async => const [];

  Future<List<Movie>> getPopularMovies() async => const [];

  Future<List<Movie>> getFeaturedMovies() async => const [];

  Future<List<Movie>> getRecentMovies() async => const [];

  Future<List<Movie>> getTrendingMovies() async => const [];

  Future<List<Movie>> getRelatedMovies(int movieId) async => const [];

  Future<List<Movie>> getFilteredMovies({
    String? genre,
    String? year,
    String? rating,
    String? sortBy,
  }) async => const [];

  Future<List<Movie>> getMoviesByIds(List<int> movieIds) async => const [];

  Future<List<String>> getMovieCategories() async => const [];

  Future<List<Review>> getMovieReviews(int movieId) async => const [];

  Future<List<Review>> getUserReviews(int userId) async => const [];

  Future<List<Review>> getRecentReviews() async => const [];

  Future<bool> submitReview(Object submission) async => false;

  Future<bool> likeReview(int reviewId) async => false;

  Future<bool> reportReview(Object report) async => false;
}
