import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/comment_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/providers/auth_provider.dart';

class CommentsRepository {
  Future<List<Comment>> fetchByMovieId(int movieId) async {
    final uri = Uri.parse('${AppConstants.baseApiUrl}/api/Comment/GetCommentsByMovieID/$movieId?movieID=$movieId');
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body);
    final data = (body is Map<String, dynamic>) ? (body['data'] ?? body['Data'] ?? body) : body;
    final list = (data is List ? data : [])
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
    // Sort newest first
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<bool> createComment({
    required int movieId,
    required int userId,
    required String content,
    int? parentId,
  }) async {
    final uri = Uri.parse('${AppConstants.baseApiUrl}/api/Comment/CreateComment');
    final body = jsonEncode({
      'movieID': movieId,
      'userID': userId,
      'content': content,
      if (parentId != null) 'parentID': parentId,
    });
    final res = await http.post(uri, headers: {
      'Content-Type': 'application/json',
    }, body: body);
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) => CommentsRepository());

final commentsProvider = FutureProvider.family<List<Comment>, int>((ref, movieId) async {
  final repo = ref.read(commentsRepositoryProvider);
  return repo.fetchByMovieId(movieId);
});

final canPostCommentProvider = Provider<bool>((ref) {
  return ref.watch(isAuthenticatedProvider);
});

final currentUserIdProvider = Provider<int?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.userId;
});
