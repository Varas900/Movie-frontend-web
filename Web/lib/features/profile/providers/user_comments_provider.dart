import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/comment_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/app_constants.dart';

class UserCommentsRepository {
  final http.Client _client;

  UserCommentsRepository({http.Client? client})
      : _client = client ?? http.Client();

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

  Future<List<Comment>> fetchByUserId(int userId) async {
    final uri = Uri.parse(
      '${AppConstants.baseApiUrl}/api/Comment/GetCommentsByUserID/$userId?userID=$userId',
    );

    final res = await _client.get(uri, headers: _authHeaders());
    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body);
    final data = _unwrap(decoded);

    final rawList = data is List ? data : const [];
    final list = <Comment>[];
    for (final e in rawList) {
      if (e is Map<String, dynamic>) {
        list.add(Comment.fromJson(e));
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

typedef CommentWithMovie = ({Comment comment, String? movieTitle});

final userCommentsRepositoryProvider = Provider<UserCommentsRepository>((ref) {
  return UserCommentsRepository();
});

final userCommentsWithMoviesProvider =
    FutureProvider.family<List<CommentWithMovie>, int>((ref, userId) async {
  final repo = ref.read(userCommentsRepositoryProvider);
  final api = ref.read(apiServiceProvider);

  final comments = await repo.fetchByUserId(userId);
  if (comments.isEmpty) return const [];

  final uniqueMovieIds = <int>{};
  for (final c in comments) {
    if (c.movieID > 0) uniqueMovieIds.add(c.movieID);
  }

  final movieTitles = <int, String?>{};
  await Future.wait(uniqueMovieIds.map((id) async {
    try {
      final movie = await api.getMovieDetails(id);
      movieTitles[id] = movie.title;
    } catch (_) {
      movieTitles[id] = null;
    }
  }));

  return comments
      .map((c) => (comment: c, movieTitle: movieTitles[c.movieID]))
      .toList(growable: false);
});
