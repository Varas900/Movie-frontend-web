import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

import '../../../core/models/comment_model.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/storage_service.dart';

class CommenterProfile {
  final int userId;
  final String userName;
  final String? avatar;

  const CommenterProfile({
    required this.userId,
    required this.userName,
    this.avatar,
  });
}

class CommenterProfilesRepository {
  final http.Client _client;
  final Map<int, CommenterProfile> _cache = <int, CommenterProfile>{};

  CommenterProfilesRepository({http.Client? client})
      : _client = client ?? CommentsRepository._defaultClient();

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

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body['data'] ?? body['Data'] ?? body['result'] ?? body;
    }
    return body;
  }

  Future<CommenterProfile?> fetchUserSlim(int userId) async {
    if (userId <= 0) return null;
    final cached = _cache[userId];
    if (cached != null) return cached;

    // Backend route is literally: /user/GetUserSlimById{userID}
    final uri = Uri.parse('${AppConstants.baseApiUrl}/user/GetUserSlimById$userId');
    final res = await _client.get(uri, headers: _authHeaders(includeJson: false));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return null;
    }

    final decoded = _safeDecode(res.body);
    final inner = decoded == null ? null : _unwrap(decoded);
    if (inner is! Map) return null;
    final data = Map<String, dynamic>.from(inner as Map);

    final userName =
        (data['userName'] ?? data['UserName'] ?? data['name'] ?? '').toString();
    final profile = (data['profile'] is Map)
        ? Map<String, dynamic>.from(data['profile'] as Map)
        : null;
    final avatar = (data['avatar'] ?? profile?['avatar'])?.toString();

    final profileModel = CommenterProfile(
      userId: userId,
      userName: userName.isEmpty ? 'User' : userName,
      avatar: (avatar != null && avatar.isNotEmpty) ? avatar : null,
    );
    _cache[userId] = profileModel;
    return profileModel;
  }

  Future<Map<int, CommenterProfile>> prefetch(Set<int> userIds,
      {int maxConcurrency = 6}) async {
    final ids = userIds.where((id) => id > 0 && !_cache.containsKey(id)).toList();
    if (ids.isEmpty) return Map<int, CommenterProfile>.from(_cache);

    // Simple concurrency limiter.
    int index = 0;
    Future<void> worker() async {
      while (index < ids.length) {
        final id = ids[index++];
        await fetchUserSlim(id);
      }
    }

    final workers = List.generate(maxConcurrency, (_) => worker());
    await Future.wait(workers);

    final result = <int, CommenterProfile>{};
    for (final id in userIds) {
      final p = _cache[id];
      if (p != null) result[id] = p;
    }
    return result;
  }
}

class CommentsRepository {
  final http.Client _client;

  CommentsRepository({http.Client? client}) : _client = client ?? _defaultClient();

  static http.Client _defaultClient() {
    if (kIsWeb) {
      return BrowserClient()..withCredentials = true;
    }
    return http.Client();
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

  Future<List<Comment>> fetchByMovieId(int movieId) async {
    final uri = Uri.parse('${AppConstants.baseApiUrl}/api/Comment/GetCommentsByMovieID/$movieId?movieID=$movieId');
    final res = await _client.get(uri, headers: _authHeaders(includeJson: false));
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
    final res = await _client.post(uri, headers: _authHeaders(), body: body);
    if (res.statusCode == 401) throw Exception('HTTP_401');
    if (res.statusCode == 403) throw Exception('HTTP_403');
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) => CommentsRepository());

final commenterProfilesRepositoryProvider =
  Provider<CommenterProfilesRepository>((ref) => CommenterProfilesRepository());

final commentsProvider = FutureProvider.family<List<Comment>, int>((ref, movieId) async {
  final repo = ref.read(commentsRepositoryProvider);
  return repo.fetchByMovieId(movieId);
});

final commenterProfilesByMovieProvider =
    FutureProvider.family<Map<int, CommenterProfile>, int>((ref, movieId) async {
  final comments = await ref.watch(commentsProvider(movieId).future);
  final ids = comments.map((c) => c.userID).toSet();
  final repo = ref.read(commenterProfilesRepositoryProvider);
  return repo.prefetch(ids);
});

final canPostCommentProvider = Provider<bool>((ref) {
  return ref.watch(isAuthenticatedProvider);
});

final currentUserIdProvider = Provider<int?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.userId;
});
