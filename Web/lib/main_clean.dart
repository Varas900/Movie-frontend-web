import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'dart:async';
import 'package:flixgo_web/core/utils/app_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:flixgo_web/core/services/auth_service.dart';
import 'package:flixgo_web/core/services/user_service.dart';
import 'package:flixgo_web/core/services/storage_service.dart';
import 'package:flixgo_web/features/actors/screens/actor_details_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flixgo_web/features/player/widgets/youtube_embed_player.dart';
import 'package:flixgo_web/core/utils/url_utils.dart';
import 'package:flixgo_web/core/utils/authz_prompt.dart';
import 'package:flixgo_web/core/services/permission_guard_client.dart';

// Simple global auth flag. In a real app, replace with Provider/Bloc.
final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
// Minimal current user info for demo profile rendering
final ValueNotifier<Map<String, String>?> currentUserInfo =
    ValueNotifier<Map<String, String>?>(null);

// Bump this whenever avatar changes to bypass browser cache.
final ValueNotifier<String> avatarCacheBuster = ValueNotifier<String>('');

// Saved movies (MovieBox) state
final ValueNotifier<Set<int>> savedMovieIds = ValueNotifier<Set<int>>(<int>{});
final ValueNotifier<Map<int, int>> savedMovieIdMap =
    ValueNotifier<Map<int, int>>(<int, int>{});
final ValueNotifier<Map<int, DateTime>> savedMovieCreatedAtMap =
  ValueNotifier<Map<int, DateTime>>(<int, DateTime>{});

int? _currentUserIdOrNull() {
  final info = currentUserInfo.value;
  final userIdStr = info?['userID'] ?? info?['userId'];
  final userId = int.tryParse(userIdStr ?? '');
  if (userId == null || userId <= 0) return null;
  return userId;
}

Future<void> refreshSavedMoviesForCurrentUser() async {
  final userId = _currentUserIdOrNull();
  if (userId == null) {
    savedMovieIds.value = <int>{};
    savedMovieIdMap.value = <int, int>{};
    savedMovieCreatedAtMap.value = <int, DateTime>{};
    return;
  }

  try {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/api/SavedMovie/GetSavedMoviesByUserID/user/$userId');
    final res = await _httpClient.get(uri, headers: _authHeaders());
    if (res.statusCode == 401 || res.statusCode == 403) {
      savedMovieIds.value = <int>{};
      savedMovieIdMap.value = <int, int>{};
      savedMovieCreatedAtMap.value = <int, DateTime>{};
      return;
    }
    if (res.statusCode != 200) return;

    final decoded = jsonDecode(res.body);
    final data = _unwrapResponseData(decoded);
    if (data is! List) return;

    final ids = <int>{};
    final map = <int, int>{};
    final createdAt = <int, DateTime>{};
    for (final item in data) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item as Map);
      final movieId = (m['movieID'] as num?)?.toInt() ??
          (m['movieId'] as num?)?.toInt() ??
          0;
      final savedId = (m['savedMovieID'] as num?)?.toInt() ??
          (m['savedMovieId'] as num?)?.toInt() ??
          (m['id'] as num?)?.toInt() ??
          0;
      final createdAtRaw = m['createdAt'] ?? m['CreatedAt'] ?? m['created_at'];
      final createdAtDt = DateTime.tryParse(createdAtRaw?.toString() ?? '');
      if (movieId > 0) {
        ids.add(movieId);
        if (savedId > 0) map[movieId] = savedId;
        if (createdAtDt != null) createdAt[movieId] = createdAtDt;
      }
    }

    savedMovieIds.value = ids;
    savedMovieIdMap.value = map;
    savedMovieCreatedAtMap.value = createdAt;
  } catch (_) {
    // ignore
  }
}

Future<void> addToMovieBox(int movieId) async {
  final userId = _currentUserIdOrNull();
  if (userId == null) throw Exception('HTTP_401');

  // optimistic
  savedMovieIds.value = Set<int>.from(savedMovieIds.value)..add(movieId);

  final uri = Uri.parse(
      '${AppConstants.baseApiUrl}/api/SavedMovie/CreateSavedMovie');
  final res = await _httpClient.post(
    uri,
    headers: _authHeaders(),
    body: jsonEncode({'userID': userId, 'movieID': movieId}),
  );

  if (res.statusCode == 401) {
    savedMovieIds.value = Set<int>.from(savedMovieIds.value)..remove(movieId);
    throw Exception('HTTP_401');
  }
  if (res.statusCode == 403) {
    savedMovieIds.value = Set<int>.from(savedMovieIds.value)..remove(movieId);
    throw Exception('HTTP_403');
  }

  if (res.statusCode == 400) {
    // treat "already saved" as ok
    await refreshSavedMoviesForCurrentUser();
    return;
  }

  if (res.statusCode != 200 && res.statusCode != 201) {
    savedMovieIds.value = Set<int>.from(savedMovieIds.value)..remove(movieId);
    throw Exception('Failed to save movie (HTTP ${res.statusCode})');
  }

  try {
    final decoded = jsonDecode(res.body);
    final data = _unwrapResponseData(decoded);
    if (data is Map) {
      final m = Map<String, dynamic>.from(data as Map);
      final savedId = (m['savedMovieID'] as num?)?.toInt() ??
          (m['savedMovieId'] as num?)?.toInt() ??
          (m['id'] as num?)?.toInt();
      if (savedId != null && savedId > 0) {
        final newMap = Map<int, int>.from(savedMovieIdMap.value);
        newMap[movieId] = savedId;
        savedMovieIdMap.value = newMap;
      }
    }
  } catch (_) {
    // ignore
  }

  await refreshSavedMoviesForCurrentUser();
}

Future<void> removeFromMovieBox(int movieId) async {
  final userId = _currentUserIdOrNull();
  if (userId == null) throw Exception('HTTP_401');

  var savedId = savedMovieIdMap.value[movieId];
  if (savedId == null || savedId <= 0) {
    await refreshSavedMoviesForCurrentUser();
    savedId = savedMovieIdMap.value[movieId];
  }

  // optimistic
  savedMovieIds.value = Set<int>.from(savedMovieIds.value)..remove(movieId);
  final newMap = Map<int, int>.from(savedMovieIdMap.value);
  newMap.remove(movieId);
  savedMovieIdMap.value = newMap;

  if (savedId == null || savedId <= 0) return;

  final uri = Uri.parse(
      '${AppConstants.baseApiUrl}/api/SavedMovie/DeleteSavedMovie/$savedId');
  final res = await _httpClient.delete(uri, headers: _authHeaders());
  if (res.statusCode == 404) return;
  if (res.statusCode == 401) {
    await refreshSavedMoviesForCurrentUser();
    throw Exception('HTTP_401');
  }
  if (res.statusCode == 403) {
    await refreshSavedMoviesForCurrentUser();
    throw Exception('HTTP_403');
  }
  if (res.statusCode != 200 && res.statusCode != 204) {
    await refreshSavedMoviesForCurrentUser();
    throw Exception('Failed to remove saved movie (HTTP ${res.statusCode})');
  }
}

Future<void> _ensureCurrentUserFromCookiesIfNeeded() async {
  if (currentUserInfo.value != null && isLoggedIn.value) return;
  try {
    final url = Uri.parse('${AppConstants.baseApiUrl}/user/me');
    final token = StorageService.getUserToken();
    final req = await html.HttpRequest.request(
      url.toString(),
      method: 'GET',
      withCredentials: true,
      requestHeaders: {
        if (token != null && token.trim().isNotEmpty)
          'Authorization': 'Bearer ${token.trim()}',
        'Accept': 'application/json',
      },
    );
    if (req.status == 200 && req.responseText != null) {
      final body = json.decode(req.responseText!);
      final data = (body is Map<String, dynamic>)
          ? (body['data'] ?? body['Data'] ?? body)
          : body;
      if (data is Map<String, dynamic>) {
        final Map<String, dynamic>? profile = (data['profile'] is Map)
            ? Map<String, dynamic>.from(data['profile'] as Map)
            : null;
        final userName =
            (data['userName'] ?? data['UserName'] ?? data['name'] ?? '')
                .toString();
        final email = (data['email'] ?? data['Email'] ?? '').toString();
        final userId =
            (data['userID'] ?? data['UserID'] ?? data['id'])?.toString();
        final firstName =
            (data['firstName'] ?? profile?['firstName'] ?? '').toString();
        final lastName =
            (data['lastName'] ?? profile?['lastName'] ?? '').toString();
        final avatar = (data['avatar'] ?? profile?['avatar'] ?? '').toString();
        final gender = (data['gender'] ?? profile?['gender'] ?? '').toString();
        final dateOfBirth =
            (data['dateOfBirth'] ?? profile?['dateOfBirth'] ?? '').toString();
        currentUserInfo.value = {
          'userName': userName,
          'email': email,
          if (userId != null) 'userID': userId,
          if (firstName.isNotEmpty) 'firstName': firstName,
          if (lastName.isNotEmpty) 'lastName': lastName,
          if (avatar.isNotEmpty) 'avatar': avatar,
          if (gender.isNotEmpty) 'gender': gender,
          if (dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
        };
        isLoggedIn.value = true;
      }
    }
  } catch (_) {
    // ignore
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // After refresh, in-memory auth is lost. Restore persisted token first,
  // then hydrate current user via /user/me (cookie or Authorization).
  await StorageService.init();
  await _ensureCurrentUserFromCookiesIfNeeded();
  runApp(const FlixGoApp());
}

final http.Client _httpClient =
  PermissionGuardClient(BrowserClient()..withCredentials = true);

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

dynamic _unwrapResponseData(dynamic body) {
  if (body is Map<String, dynamic>) {
    return body['data'] ?? body['Data'] ?? body['result'] ?? body;
  }
  return body;
}

String _previewBody(String s, {int max = 400}) {
  if (s.length <= max) return s;
  return s.substring(0, max);
}

Future<Movie> _fetchBasicMovieByIdForMovieBox(int movieId) async {
  final uri =
      Uri.parse('${AppConstants.baseApiUrl}/api/Movie/GetMovieById/$movieId');
  final res = await _httpClient.get(uri, headers: _authHeaders());
  if (res.statusCode != 200) {
    throw Exception(
        'GetMovieById HTTP ${res.statusCode}: ${_previewBody(res.body)}');
  }

  final body = jsonDecode(res.body);
  final data = _unwrapResponseData(body);
  if (data is! Map<String, dynamic>) {
    throw Exception('Unexpected response shape');
  }

  final title = (data['title'] as String?) ??
      (data['originalTitle'] as String?) ??
      'Untitled';
  final description = (data['description'] as String?) ?? '';
  final imageUrl = (data['image'] as String?) ??
      'https://via.placeholder.com/300x400?text=No+Image';

  final releaseDate = DateTime.tryParse(data['releaseDate']?.toString() ?? '');
  final yearInt = (data['year'] as num?)?.toInt();
  final year = (yearInt != null && yearInt > 0)
      ? yearInt.toString()
      : (releaseDate != null ? releaseDate.year.toString() : '—');

  final rated = (data['rated'] as String?)?.trim();
  final rating = (rated != null && rated.isNotEmpty) ? rated : 'NR';
  final popularity = (data['popularity'] as num?)?.toDouble() ?? 0.0;

  return Movie(
    id: (data['movieID'] as num?)?.toInt() ?? movieId,
    title: title,
    description: description,
    imageUrl: imageUrl,
    year: year,
    rating: rating,
    popularity: popularity,
    genres: const [],
    duration: 0,
    actors: const [],
    releaseDate: releaseDate,
    regionName: null,
  );
}

// Movie Data Models
class Movie {
  final int id;
  final String title;
  final String description;
  final String imageUrl;
  final String year;
  final String rating;
  final double popularity;
  final List<String> genres;
  final int duration; // in minutes
  final int? durationSeconds;
  final String? movieType;
  final int? totalSeasons;
  final int? totalEpisodes;
  final List<Actor> actors;
  final DateTime? releaseDate;
  final String? regionName;

  Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.year,
    required this.rating,
    required this.popularity,
    required this.genres,
    required this.duration,
    this.durationSeconds,
    this.movieType,
    this.totalSeasons,
    this.totalEpisodes,
    required this.actors,
    this.releaseDate,
    this.regionName,
  });

  bool get isSeries {
    final t = (movieType ?? '').toLowerCase().trim();
    if (t == 'series' || t == 'tv' || t == 'tvshow' || t == 'tv_show')
      return true;
    if ((totalSeasons ?? 0) > 0) return true;
    if ((totalEpisodes ?? 0) > 0) return true;
    return false;
  }
}

String _formatAny(dynamic v) {
  if (v == null) return 'null';
  if (v is String) return v;
  if (v is num || v is bool) return v.toString();
  try {
    return jsonEncode(v);
  } catch (_) {
    return v.toString();
  }
}

class Actor {
  final int personId;
  final String name;
  final String character;
  final String? avatarUrl;

  const Actor({
    required this.personId,
    required this.name,
    required this.character,
    this.avatarUrl,
  });
}

// Mutable app-wide movie list populated from API (empty until fetched)
List<Movie> appMovies = [];

// Demo playable source holder
class _DemoSource {
  final int id;
  final String url;
  final List<Map<String, String>> subtitles;

  const _DemoSource({
    required this.id,
    required this.url,
    required this.subtitles,
  });
}

// Simple Comment DTO for demo
class CommentDemo {
  final int commentID;
  final int movieID;
  final int userID;
  final String? userName;
  final String content;
  final int? parentID;
  final bool isEdited;
  final int? likeCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommentDemo({
    required this.commentID,
    required this.movieID,
    required this.userID,
    this.userName,
    required this.content,
    this.parentID,
    required this.isEdited,
    this.likeCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommentDemo.fromJson(Map<String, dynamic> json) {
    int readInt(String a, String b, String c) {
      return (json[a] as num?)?.toInt() ??
          (json[b] as num?)?.toInt() ??
          (json[c] as num?)?.toInt() ??
          0;
    }

    return CommentDemo(
        commentID: readInt('commentID', 'commentId', 'id'),
        movieID: readInt('movieID', 'movieId', 'movie'),
        userID: readInt('userID', 'userId', 'user'),
      userName: (json['userName'] ?? json['username'] ?? json['fullName'])
          as String?,
      content: json['content'] as String? ?? '',
      parentID: (json['parentID'] as num?)?.toInt() ??
          (json['parentId'] as num?)?.toInt(),
      isEdited: (json['isEdited'] as bool?) ?? (json['edited'] as bool?) ?? false,
      likeCount: (json['likeCount'] as num?)?.toInt() ??
          (json['likes'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class GroupedCommentsDemo {
  final List<CommentDemo> parents;
  final Map<int, List<CommentDemo>> repliesByParent;
  GroupedCommentsDemo(this.parents, this.repliesByParent);
}

class _UserSlimLite {
  final int userId;
  final String userName;
  final String? avatar;

  const _UserSlimLite({
    required this.userId,
    required this.userName,
    this.avatar,
  });
}

class FlixGoApp extends StatelessWidget {
  const FlixGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FlixGo - Movies & TV Shows',
      theme: ThemeData.dark(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final GoRouter _router = GoRouter(
  redirect: (context, state) {
    final path = state.uri.path;
    final hasToken =
        (StorageService.getUserToken()?.trim().isNotEmpty ?? false);
    final loggedIn = isLoggedIn.value || hasToken;

    const publicPaths = <String>{
      '/',
      '/signin',
      '/signup',
      '/search',
      '/forgot-password',
      '/check-email',
      '/verify-email',
    };

    final isMovieDetails = path.startsWith('/movie/');

    if (!loggedIn && !publicPaths.contains(path) && !isMovieDetails) {
      return '/signin';
    }

    if (loggedIn && (path == '/signin' || path == '/signup')) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/movie/:id',
      builder: (context, state) {
        final movieId = int.parse(state.pathParameters['id']!);
        final matches = appMovies.where((m) => m.id == movieId).toList();
        return MovieDetailsScreen(
          movieId: movieId,
          initialMovie: matches.isNotEmpty ? matches.first : null,
        );
      },
    ),
    GoRoute(
      path: '/actor/:id',
      builder: (context, state) {
        final actorId = int.parse(state.pathParameters['id']!);
        return ActorDetailsScreen(actorId: actorId);
      },
    ),
    GoRoute(
      path: '/player/:id',
      builder: (context, state) {
        final movieId = int.parse(state.pathParameters['id']!);
        final matches = appMovies.where((m) => m.id == movieId).toList();
        return matches.isNotEmpty
            ? VideoPlayerScreen(movie: matches.first)
            : const HomeScreen();
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/moviebox',
      builder: (context, state) => const MovieBoxScreen(),
    ),
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) {
        final query = state.uri.queryParameters['q'] ?? '';
        return SearchScreen(query: query);
      },
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/check-email',
      builder: (context, state) => const CheckEmailScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) {
        final userId =
            int.tryParse(state.uri.queryParameters['userID'] ?? '') ?? 0;
        return VerifyEmailScreen(userId: userId);
      },
    ),
  ],
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _didSync = false;

  @override
  void initState() {
    super.initState();
    _syncAuthFromCookies();
    _fetchAllMovies();
  }

  Future<void> _syncAuthFromCookies() async {
    if (_didSync) return;
    _didSync = true;
    if (isLoggedIn.value) return;
    try {
      final url = Uri.parse('${AppConstants.baseApiUrl}/user/me');
      final req = await html.HttpRequest.request(
        url.toString(),
        method: 'GET',
        withCredentials: true,
      );
      if (req.status == 200 && req.responseText != null) {
        final body = json.decode(req.responseText!);
        final data = (body is Map<String, dynamic>)
            ? (body['data'] ?? body['Data'] ?? body)
            : body;
        if (data is Map<String, dynamic>) {
          final Map<String, dynamic>? profile = (data['profile'] is Map)
              ? Map<String, dynamic>.from(data['profile'] as Map)
              : null;
          final userName =
              (data['userName'] ?? data['UserName'] ?? data['name'] ?? '')
                  .toString();
          final email = (data['email'] ?? data['Email'] ?? '').toString();
          final userId =
              (data['userID'] ?? data['UserID'] ?? data['id'])?.toString();
          final firstName =
              (data['firstName'] ?? profile?['firstName'] ?? '').toString();
          final lastName =
              (data['lastName'] ?? profile?['lastName'] ?? '').toString();
          final avatar = (data['avatar'] ?? profile?['avatar'] ?? '').toString();
          final gender = (data['gender'] ?? profile?['gender'] ?? '').toString();
          final dateOfBirth =
              (data['dateOfBirth'] ?? profile?['dateOfBirth'] ?? '').toString();
          currentUserInfo.value = {
            'userName': userName,
            'email': email,
            if (userId != null) 'userID': userId,
            if (firstName.isNotEmpty) 'firstName': firstName,
            if (lastName.isNotEmpty) 'lastName': lastName,
            if (avatar.isNotEmpty) 'avatar': avatar,
            if (gender.isNotEmpty) 'gender': gender,
            if (dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
          };
          if (avatar.isNotEmpty) {
            avatarCacheBuster.value =
                DateTime.now().millisecondsSinceEpoch.toString();
          }
          isLoggedIn.value = true;
          unawaited(refreshSavedMoviesForCurrentUser());
        }
      }
    } catch (_) {
      // ignore
    }
  }

  final TextEditingController _searchController = TextEditingController();
  List<Movie> filteredMovies = [];
  String selectedGenre = 'All';
  bool _isLoading = true;

  // Dynamic genres populated from API tags
  List<String> availableGenres = ['All'];
  final Map<String, int> _genreNameToTagId = {};
  final Map<int, String> _tagIdToGenreName = {};
  Set<int>? _activeGenreMovieIds;

  void _filterMovies(String query) {
    setState(() {
      filteredMovies = appMovies.where((movie) {
        final matchesQuery =
            movie.title.toLowerCase().contains(query.toLowerCase()) ||
                movie.description.toLowerCase().contains(query.toLowerCase());
        final matchesGenre = selectedGenre == 'All' ||
            _activeGenreMovieIds == null ||
            _activeGenreMovieIds!.contains(movie.id);
        return matchesQuery && matchesGenre;
      }).toList();
    });
  }

  void _selectGenre(String genre) {
    if (genre == selectedGenre) return;
    setState(() {
      selectedGenre = genre;
    });
    _applyGenreFilter(genre);
  }

  Future<void> _applyGenreFilter(String genre) async {
    final query = _searchController.text;
    if (genre == 'All') {
      _activeGenreMovieIds = null;
      _filterMovies(query);
      return;
    }

    final tagId = _genreNameToTagId[genre];
    if (tagId == null) {
      _filterMovies(query);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final ids = await _fetchMovieIdsForTag(tagId);
      _activeGenreMovieIds = ids;
      final subset = appMovies.where((m) => ids.contains(m.id)).where((m) {
        final q = query.toLowerCase();
        return m.title.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q);
      }).toList();
      if (!mounted) return;
      setState(() {
        filteredMovies = subset;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _filterMovies(query);
    }
  }

  Future<void> _fetchAllMovies() async {
    try {
      final url = Uri.parse(
          '${AppConstants.baseApiUrl}/api/Movie/GetAllMoviesMainScreen/mainScreen');
      final res = await _httpClient.get(url, headers: _authHeaders());
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = _unwrapResponseData(decoded);
        if (data is! List) {
          throw Exception('mainScreen returned unexpected shape');
        }
        final List<dynamic> items = data;
        final fetched = items.map((e) {
          final m = e as Map<String, dynamic>;
          return Movie(
            id: (m['movieID'] as num).toInt(),
            title: (m['title'] as String?) ??
                (m['originalTitle'] as String?) ??
                'Untitled',
            description: (m['description'] as String?) ?? '',
            imageUrl: (m['image'] as String?) ??
                'https://via.placeholder.com/300x400?text=No+Image',
            year: '—',
            rating: 'NR',
            popularity: 0.0,
            // Temporary; replaced with real tag genres below
            genres: const [],
            duration: 0,
            durationSeconds: null,
            movieType: null,
            totalSeasons: null,
            totalEpisodes: null,
            actors: const [],
            releaseDate: null,
            regionName: null,
          );
        }).toList();

        // Fetch tags (genres) for the home filter bar.
        // Filtering will use GetMoviesByTagIDs/getMovieByTagID on demand.
        final allTags = await _fetchAllTags();
        final tagIdToName = <int, String>{};
        for (final t in allTags) {
          final id = (t['tagID'] as num?)?.toInt();
          final name = t['tagName']?.toString().trim() ?? '';
          if (id == null || name.isEmpty) continue;
          tagIdToName[id] = name;
        }
        final names = tagIdToName.values.toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        _genreNameToTagId
          ..clear()
          ..addAll({
            for (final entry in tagIdToName.entries) entry.value: entry.key,
          });
        _tagIdToGenreName
          ..clear()
          ..addAll({
            for (final entry in tagIdToName.entries) entry.key: entry.value,
          });

        setState(() {
          availableGenres = ['All', ...names];
          appMovies = fetched;
          filteredMovies = fetched;
          _isLoading = false;
        });

        // Enrich home cards with watchNow fields (year/rating/duration/popularity)
        // because mainScreen doesn't include them.
        unawaited(_enrichMoviesFromWatchNow());
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enrichMoviesFromWatchNow() async {
    if (appMovies.isEmpty) return;

    // Fetch sequentially to avoid spamming the API.
    final updated = <Movie>[];
    for (final movie in appMovies) {
      try {
        Map<String, dynamic>? data;

        final watchNowUri = Uri.parse(
            '${AppConstants.baseApiUrl}/api/Movie/GetWatchNowMovieByID/watchNow/${movie.id}');
        final watchNowRes =
            await _httpClient.get(watchNowUri, headers: _authHeaders());
        if (watchNowRes.statusCode == 200) {
          final decoded = jsonDecode(watchNowRes.body);
          final unwrapped = _unwrapResponseData(decoded);
          if (unwrapped is Map<String, dynamic>) {
            data = unwrapped;
          }
        } else if (watchNowRes.statusCode == 401 ||
            watchNowRes.statusCode == 403) {
          // Guest/expired auth: fall back to anonymous basic endpoint.
          final basicUri = Uri.parse(
              '${AppConstants.baseApiUrl}/api/Movie/GetMovieById/${movie.id}');
          final basicRes =
              await _httpClient.get(basicUri, headers: _authHeaders());
          if (basicRes.statusCode == 200) {
            final decoded = jsonDecode(basicRes.body);
            final unwrapped = _unwrapResponseData(decoded);
            if (unwrapped is Map<String, dynamic>) {
              data = unwrapped;
            }
          }
        }

        if (data == null) {
          updated.add(movie);
          continue;
        }

        final releaseDate =
            DateTime.tryParse(data['releaseDate']?.toString() ?? '');
        final yearInt = (data['year'] as num?)?.toInt();
        final year = (yearInt != null && yearInt > 0)
            ? yearInt.toString()
            : (releaseDate != null ? releaseDate.year.toString() : movie.year);

        final rated = (data['rated'] as String?)?.trim();
        final rating =
            (rated != null && rated.isNotEmpty) ? rated : movie.rating;

        final popularity =
            (data['popularity'] as num?)?.toDouble() ?? movie.popularity;

        final durationSeconds = (data['durationSeconds'] as num?)?.toInt();
        final durationMinutes = durationSeconds == null
            ? movie.duration
            : (durationSeconds / 60.0).round();

        // Region might be returned as { region: { regionName } } or { regions: { regionName } }
        final region = data['region'] ?? data['regions'];
        final regionName = region is Map<String, dynamic>
            ? (region['regionName'] as String?)
            : movie.regionName;

        updated.add(Movie(
          id: movie.id,
          title: (data['title'] as String?) ?? movie.title,
          description: (data['description'] as String?) ?? movie.description,
          imageUrl: (data['image'] as String?) ?? movie.imageUrl,
          year: year,
          rating: rating,
          popularity: popularity,
          genres: movie.genres,
          duration: durationMinutes,
          durationSeconds: durationSeconds ?? movie.durationSeconds,
          movieType: (data['movieType'] as String?) ?? movie.movieType,
          totalSeasons:
              (data['totalSeasons'] as num?)?.toInt() ?? movie.totalSeasons,
          totalEpisodes:
              (data['totalEpisodes'] as num?)?.toInt() ?? movie.totalEpisodes,
          actors: movie.actors,
          releaseDate: releaseDate ?? movie.releaseDate,
          regionName: regionName,
        ));
      } catch (_) {
        updated.add(movie);
      }
    }

    if (!mounted) return;
    setState(() {
      appMovies = updated;
    });

    // Re-apply current filters so the UI updates.
    if (selectedGenre == 'All') {
      _filterMovies(_searchController.text);
    } else {
      unawaited(_applyGenreFilter(selectedGenre));
    }
  }

  // Fetch all tags (genres) from API
  Future<List<Map<String, dynamic>>> _fetchAllTags() async {
    final uri =
        Uri.parse('${AppConstants.baseApiUrl}/movie/Tag/GetAllTags/getALlTags');
    final res = await _httpClient.get(uri, headers: _authHeaders());
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(res.body);
    final data = _unwrapResponseData(body);
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  // Fetch movie IDs for a given tag
  Future<Set<int>> _fetchMovieIdsForTag(int tagId) async {
    try {
      final uri = Uri.parse(
          '${AppConstants.baseApiUrl}/movie/MovieTag/GetMoviesByTagIDs/getMovieByTagID?tagID=$tagId');
      final res = await _httpClient.get(uri, headers: _authHeaders());
      if (res.statusCode != 200) return <int>{};
      final body = jsonDecode(res.body);
      final data = _unwrapResponseData(body);
      final out = <int>{};
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final id = (item['movieID'] as num?)?.toInt();
            if (id != null) out.add(id);
          }
        }
      }
      return out;
    } catch (_) {
      return <int>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // App Bar with Search and Profile
          SliverAppBar(
            expandedHeight: 80,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              title: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final showTagline = w > 720;
                  final searchW = w > 980 ? 250.0 : (w > 720 ? 200.0 : 160.0);
                  return Row(
                    children: [
                      const Text(
                        'FlixGo',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: showTagline ? 24 : 12),
                      if (showTagline)
                        const Expanded(
                          child: Text(
                            'Discover Amazing Movies & TV Shows',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Search Bar - responsive width
                      SizedBox(
                        width: searchW,
                        height: 35,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Search movies...',
                              hintStyle:
                                  TextStyle(color: Colors.grey, fontSize: 14),
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey, size: 20),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: _filterMovies,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Profile / Auth controls
                      ValueListenableBuilder<bool>(
                        valueListenable: isLoggedIn,
                        builder: (context, loggedIn, _) {
                          if (loggedIn) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'MovieBox',
                                  onPressed: () => context.go('/moviebox'),
                                  icon: const Icon(Icons.bookmark_border,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 2),
                                GestureDetector(
                                  onTap: () => context.go('/profile'),
                                  child: ValueListenableBuilder<Map<String, String>?>(
                                    valueListenable: currentUserInfo,
                                    builder: (context, info, _) {
                                      final avatarUrl = cacheBustUrl(
                                        resolveApiUrl(info?['avatar']),
                                        cacheKey: avatarCacheBuster.value,
                                      );
                                      final name = (info?['userName'] ?? '').toString();
                                      return CircleAvatar(
                                        backgroundColor: Colors.red,
                                        radius: 18,
                                        backgroundImage:
                                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                        child: avatarUrl.isNotEmpty
                                            ? null
                                            : Icon(Icons.person,
                                                color: Colors.white, size: 18),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => context.go('/signin'),
                                child: const Text('Sign in'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                ),
                                onPressed: () => context.go('/signup'),
                                child: const Text('Sign up'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.black],
                  ),
                ),
              ),
            ),
          ),

          // Genre Filter
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Genres',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableGenres.length,
                      itemBuilder: (context, index) {
                        final genre = availableGenres[index];
                        final isSelected = selectedGenre == genre;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => _selectGenre(genre),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    isSelected ? Colors.red : Colors.grey[800],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                genre,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.grey,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Featured Movie
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Featured',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    SizedBox(
                      height: 280,
                      child: Center(
                        child: SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (filteredMovies.isNotEmpty)
                    GestureDetector(
                      onTap: () =>
                          context.go('/movie/${filteredMovies.first.id}'),
                      child: Container(
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(filteredMovies.first.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8)
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filteredMovies.first.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${filteredMovies.first.year} • ${filteredMovies.first.rating} • ${filteredMovies.first.duration}m',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  filteredMovies.first.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => context.go(
                                          '/player/${filteredMovies.first.id}'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Play'),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go(
                                          '/movie/${filteredMovies.first.id}'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.white),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.info_outline),
                                      label: const Text('More Info'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Movies Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedGenre == 'All'
                        ? 'All Movies'
                        : '$selectedGenre Movies',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Center(
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        // Let the grid decide column count based on available width
                        // to minimize unused space between cards
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        // Movie posters are typically 2:3 (w:h)
                        childAspectRatio: 2 / 3,
                      ),
                      itemCount: filteredMovies.length,
                      itemBuilder: (context, index) {
                        final movie = filteredMovies[index];
                        return GestureDetector(
                          onTap: () => context.go('/movie/${movie.id}'),
                          child: Container(
                            // Ensure the tile fills its grid slot fully
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Poster image fills entire tile
                                  Positioned.fill(
                                    child: Image.network(
                                      movie.imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // Gradient overlay
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.7),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bottom labels
                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    bottom: 12,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          movie.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${movie.year} • ⭐ ${movie.popularity}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Movie Details Screen
class MovieDetailsScreen extends StatefulWidget {
  final int movieId;
  final Movie? initialMovie;

  const MovieDetailsScreen({
    super.key,
    required this.movieId,
    required this.initialMovie,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  Movie? _movie;
  bool _loading = true;
  String? _error;

  bool _episodesLoading = false;
  String? _episodesError;
  int? _episodesForMovieId;
  List<Map<String, dynamic>> _episodes = const [];
  int? _selectedSeason;
  Future<void>? _episodesLoadTask;

    int? _firstEpisodeIdFromLoaded() {
    if (_episodes.isEmpty) return null;
      final withSeason = _episodes.where((e) {
        final season = (e['seasonNumber'] as num?)?.toInt() ??
          (e['season'] as num?)?.toInt() ??
          0;
        return season > 0;
      }).toList();
      final source = withSeason.isNotEmpty ? withSeason : _episodes;
      final sorted = List<Map<String, dynamic>>.from(source);
    sorted.sort((a, b) {
        final saRaw = (a['seasonNumber'] as num?)?.toInt() ??
          (a['season'] as num?)?.toInt() ??
          0;
        final sbRaw = (b['seasonNumber'] as num?)?.toInt() ??
          (b['season'] as num?)?.toInt() ??
          0;
        final sa = saRaw > 0 ? saRaw : 999;
        final sb = sbRaw > 0 ? sbRaw : 999;
      if (sa != sb) return sa.compareTo(sb);

        final eaRaw = (a['episodeNumber'] as num?)?.toInt() ??
          (a['episode'] as num?)?.toInt() ??
          0;
        final ebRaw = (b['episodeNumber'] as num?)?.toInt() ??
          (b['episode'] as num?)?.toInt() ??
          0;
        final ea = eaRaw > 0 ? eaRaw : 999;
        final eb = ebRaw > 0 ? ebRaw : 999;
      if (ea != eb) return ea.compareTo(eb);

      final ia = (a['episodeID'] as num?)?.toInt() ??
        (a['episodeId'] as num?)?.toInt() ??
        (a['id'] as num?)?.toInt() ??
        0;
      final ib = (b['episodeID'] as num?)?.toInt() ??
        (b['episodeId'] as num?)?.toInt() ??
        (b['id'] as num?)?.toInt() ??
        0;
      return ia.compareTo(ib);
    });

    final first = sorted.first;
    final id = (first['episodeID'] as num?)?.toInt() ??
      (first['episodeId'] as num?)?.toInt() ??
      (first['id'] as num?)?.toInt() ??
      0;
    return id > 0 ? id : null;
    }

  @override
  void initState() {
    super.initState();
    _movie = widget.initialMovie;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Prefer watchNow (richer data) when authenticated.
      // If the backend returns 401/403 (guest/expired auth), fall back to the
      // anonymous basic endpoint so all users can see movie details.
      final watchNow = await _fetchWatchNowMovie(widget.movieId);
      final core = watchNow ?? await _fetchBasicMovieById(widget.movieId);

      final results = await Future.wait([
        _fetchTagsByMovie(widget.movieId),
        _fetchUserRatingLabel(widget.movieId),
      ]);

      final tags = results[0] as List<String>;
      final userRatingLabel = results[1] as String;

      final merged = Movie(
        id: core.id,
        title: core.title,
        description: core.description,
        imageUrl: core.imageUrl,
        year: core.year,
        rating: userRatingLabel.isNotEmpty ? userRatingLabel : core.rating,
        popularity: core.popularity,
        genres: tags.isNotEmpty ? tags : core.genres,
        duration: core.duration,
        durationSeconds: core.durationSeconds,
        movieType: core.movieType,
        totalSeasons: core.totalSeasons,
        totalEpisodes: core.totalEpisodes,
        actors: core.actors,
        releaseDate: core.releaseDate,
        regionName: core.regionName,
      );

      if (!mounted) return;
      setState(() {
        _movie = merged;
        _loading = false;
      });

      if (merged.isSeries) {
        unawaited(_loadEpisodes(merged.id));
      } else {
        if (!mounted) return;
        setState(() {
          _episodesForMovieId = merged.id;
          _episodes = const [];
          _episodesError = null;
          _episodesLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadEpisodes(int movieId) async {
    if (_episodesForMovieId == movieId) {
      if (_episodesLoading && _episodesLoadTask != null) {
        await _episodesLoadTask;
        return;
      }
      if (_episodes.isNotEmpty || _episodesError != null) return;
    }

    final completer = Completer<void>();
    _episodesLoadTask = completer.future;

    setState(() {
      _episodesLoading = true;
      _episodesError = null;
      _episodesForMovieId = movieId;
      _episodes = const [];
    });
    try {
      final uri = Uri.parse(
          '${AppConstants.baseApiUrl}/api/Episode/GetEpisodesByMovieId/getbyMovie/$movieId');
      final res = await _httpClient.get(uri, headers: _authHeaders());
      if (res.statusCode != 200) {
        throw Exception(
            'Episodes HTTP ${res.statusCode}: ${_previewBody(res.body)}');
      }
      final decoded = jsonDecode(res.body);
      final data = _unwrapResponseData(decoded);
      if (data is! List) {
        throw Exception('Episodes returned unexpected shape');
      }
      final eps = <Map<String, dynamic>>[];
      for (final e in data) {
        if (e is Map<String, dynamic>) {
          eps.add(e);
        } else if (e is Map) {
          eps.add(Map<String, dynamic>.from(e as Map));
        }
      }
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        final seasons = eps
            .map((e) =>
                (e['seasonNumber'] as num?)?.toInt() ??
                (e['season'] as num?)?.toInt() ??
                0)
            .where((s) => s > 0)
            .toSet()
            .toList()
          ..sort();
        if (seasons.isNotEmpty &&
            (_selectedSeason == null || !seasons.contains(_selectedSeason))) {
          _selectedSeason = seasons.first;
        }
        _episodesLoading = false;
      });
      completer.complete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _episodesLoading = false;
          _episodesError = e.toString();
        });
      }
      completer.complete();
    } finally {
      _episodesLoadTask = null;
    }
  }

  Future<Movie?> _fetchWatchNowMovie(int movieId) async {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/api/Movie/GetWatchNowMovieByID/watchNow/$movieId');
    final res = await _httpClient.get(uri, headers: _authHeaders());
    if (res.statusCode == 401 || res.statusCode == 403) {
      return null;
    }
    if (res.statusCode != 200) {
      throw Exception(
          'watchNow HTTP ${res.statusCode}: ${_previewBody(res.body)}');
    }

    final body = jsonDecode(res.body);
    final data = _unwrapResponseData(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected response shape');
    }

    final title = (data['title'] as String?) ??
        (data['originalTitle'] as String?) ??
        'Untitled';
    final description = (data['description'] as String?) ?? '';
    final imageUrl = (data['image'] as String?) ??
        'https://via.placeholder.com/300x400?text=No+Image';

    final releaseDate =
        DateTime.tryParse(data['releaseDate']?.toString() ?? '');
    final yearInt = (data['year'] as num?)?.toInt();
    final year = (yearInt != null && yearInt > 0)
        ? yearInt.toString()
        : (releaseDate != null ? releaseDate.year.toString() : '—');

    final rating = (data['rated'] as String?)?.trim().isNotEmpty == true
        ? (data['rated'] as String)
        : 'NR';

    final popularity = (data['popularity'] as num?)?.toDouble() ?? 0.0;

    final durationSeconds = (data['durationSeconds'] as num?)?.toInt();
    final durationMinutes =
        durationSeconds == null ? 0 : (durationSeconds / 60.0).round();

    final region = data['region'];
    final regionName = region is Map<String, dynamic>
        ? (region['regionName'] as String?)
        : null;

    final tags = data['tags'];
    final genres = <String>[];
    if (tags is List) {
      for (final t in tags) {
        if (t is Map<String, dynamic>) {
          final name = (t['tagName'] as String?)?.trim();
          if (name != null && name.isNotEmpty) genres.add(name);
        }
      }
    }
    genres.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final actorsRaw = data['actors'];
    final actors = <Actor>[];
    if (actorsRaw is List) {
      for (final a in actorsRaw) {
        if (a is Map<String, dynamic>) {
          final personId = (a['personID'] as num?)?.toInt() ??
              (a['personId'] as num?)?.toInt() ??
              (a['id'] as num?)?.toInt() ??
              0;
          final fullName = (a['fullName'] as String?)?.trim();
          if (fullName == null || fullName.isEmpty) continue;
          final character = (a['characterName'] as String?)?.trim() ??
              (a['role'] as String?)?.trim() ??
              '';
          actors.add(Actor(
            personId: personId,
            name: fullName,
            character: character,
            avatarUrl: a['avatar'] as String?,
          ));
        }
      }
    }

    return Movie(
      id: (data['movieID'] as num?)?.toInt() ?? movieId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      year: year,
      rating: rating,
      popularity: popularity,
      genres: genres,
      duration: durationMinutes,
      durationSeconds: durationSeconds,
      movieType: (data['movieType'] as String?),
      totalSeasons: (data['totalSeasons'] as num?)?.toInt(),
      totalEpisodes: (data['totalEpisodes'] as num?)?.toInt(),
      actors: actors,
      releaseDate: releaseDate,
      regionName: regionName,
    );
  }

  Future<Movie> _fetchBasicMovieById(int movieId) async {
    final uri =
        Uri.parse('${AppConstants.baseApiUrl}/api/Movie/GetMovieById/$movieId');
    final res = await _httpClient.get(uri, headers: _authHeaders());
    if (res.statusCode != 200) {
      throw Exception(
          'GetMovieById HTTP ${res.statusCode}: ${_previewBody(res.body)}');
    }

    final body = jsonDecode(res.body);
    final data = _unwrapResponseData(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected response shape');
    }

    final title = (data['title'] as String?) ??
        (data['originalTitle'] as String?) ??
        'Untitled';
    final description = (data['description'] as String?) ?? '';
    final imageUrl = (data['image'] as String?) ??
        'https://via.placeholder.com/300x400?text=No+Image';

    final releaseDate =
        DateTime.tryParse(data['releaseDate']?.toString() ?? '');
    final yearInt = (data['year'] as num?)?.toInt();
    final year = (yearInt != null && yearInt > 0)
        ? yearInt.toString()
        : (releaseDate != null ? releaseDate.year.toString() : '—');

    final rated = (data['rated'] as String?)?.trim();
    final rating = (rated != null && rated.isNotEmpty) ? rated : 'NR';

    final popularity = (data['popularity'] as num?)?.toDouble() ?? 0.0;

    final durationSeconds = (data['durationSeconds'] as num?)?.toInt();
    final durationMinutes =
        durationSeconds == null ? 0 : (durationSeconds / 60.0).round();

    // Region might be returned as { region: { regionName } } or { regions: { regionName } }
    final region = data['region'] ?? data['regions'];
    final regionName = region is Map<String, dynamic>
        ? (region['regionName'] as String?)
        : null;

    // Attempt to derive genres from embedded tags if present.
    final genres = <String>[];
    final tags = data['tags'];
    if (tags is List) {
      for (final t in tags) {
        if (t is Map<String, dynamic>) {
          final name = (t['tagName'] as String?)?.trim();
          if (name != null && name.isNotEmpty) genres.add(name);
        }
      }
    }
    final movieTags = data['movieTags'];
    if (genres.isEmpty && movieTags is List) {
      for (final mt in movieTags) {
        if (mt is Map<String, dynamic>) {
          final tag = mt['tags'] ?? mt['tag'];
          if (tag is Map<String, dynamic>) {
            final name = (tag['tagName'] as String?)?.trim();
            if (name != null && name.isNotEmpty) genres.add(name);
          }
        }
      }
    }
    genres.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Movie(
      id: (data['movieID'] as num?)?.toInt() ?? movieId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      year: year,
      rating: rating,
      popularity: popularity,
      genres: genres,
      duration: durationMinutes,
      durationSeconds: durationSeconds,
      movieType: (data['movieType'] as String?),
      totalSeasons: (data['totalSeasons'] as num?)?.toInt(),
      totalEpisodes: (data['totalEpisodes'] as num?)?.toInt(),
      actors: const [],
      releaseDate: releaseDate,
      regionName: regionName,
    );
  }

  Future<List<String>> _fetchTagsByMovie(int movieId) async {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/MovieTag/GetTagsByMovie/$movieId');
    final res = await _httpClient.get(uri, headers: _authHeaders());
    if (res.statusCode != 200) return const [];
    final decoded = jsonDecode(res.body);
    final data = _unwrapResponseData(decoded);
    final out = <String>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final name = (item['tagName'] ?? item['TagName'])?.toString().trim();
          if (name != null && name.isNotEmpty) out.add(name);
        }
      }
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  Future<String> _fetchUserRatingLabel(int movieId) async {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/api/UserRating/GetAllUserRatingsByMovieId/$movieId');
    final res = await _httpClient.get(uri, headers: _authHeaders());
    if (res.statusCode != 200) return '';
    final decoded = jsonDecode(res.body);
    final data = _unwrapResponseData(decoded);
    if (data is! List) return '';

    final values = <double>[];
    for (final item in data) {
      if (item is Map) {
        final dynamic v = item['ratingValue'] ??
            item['rating'] ??
            item['score'] ??
            item['stars'] ??
            item['point'] ??
            item['value'];
        if (v is num) {
          values.add(v.toDouble());
        } else if (v is String) {
          final parsed = double.tryParse(v);
          if (parsed != null) values.add(parsed);
        }
      }
    }
    if (values.isEmpty) return '';
    final avg = values.reduce((a, b) => a + b) / values.length;
    return '⭐ ${avg.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _movie == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _movie == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Failed to load movie details',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final movie = _movie!;
    final durationSec = movie.durationSeconds ??
        (movie.duration > 0 ? movie.duration * 60 : null);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          if (_error != null)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                color: Colors.red.withOpacity(0.12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Details load failed: $_error',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          SliverAppBar(
            expandedHeight: 420,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop image
                  Image.network(
                    movie.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  // Gradient scrim for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.95),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.go('/'),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Meta chips
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaChip(label: movie.year),
                          _MetaChip(label: movie.rating),
                          _MetaChip(
                              label: durationSec == null
                                  ? '— sec'
                                  : '$durationSec sec'),
                          if (movie.releaseDate != null)
                            _MetaChip(
                                label: DateFormat('yyyy-MM-dd')
                                    .format(movie.releaseDate!)),
                          if ((movie.regionName ?? '').trim().isNotEmpty)
                            _MetaChip(label: movie.regionName!.trim()),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                movie.popularity.toString(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Actions
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 520;
                          return isNarrow
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _PlayButton(onTap: () {
                                      () async {
                                        if (movie.isSeries) {
                                          await _loadEpisodes(movie.id);
                                          final firstEpId =
                                              _firstEpisodeIdFromLoaded();
                                          if (firstEpId != null) {
                                            if (!context.mounted) return;
                                            showDialog(
                                              context: context,
                                              barrierDismissible: true,
                                              builder: (_) =>
                                                  InlinePlayerDialogDemo.episode(
                                                episodeId: firstEpId,
                                                title: 'Episode 1',
                                              ),
                                            );
                                            return;
                                          }
                                        }
                                        if (!context.mounted) return;
                                        showDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          builder: (_) => InlinePlayerDialogDemo(
                                              movieId: movie.id),
                                        );
                                      }();
                                    }),
                                    const SizedBox(height: 12),
                                    ValueListenableBuilder<Set<int>>(
                                      valueListenable: savedMovieIds,
                                      builder: (context, ids, _) {
                                        final isSaved = ids.contains(movie.id);
                                        return _AddToListButton(
                                          isSaved: isSaved,
                                          onTap: () async {
                                            try {
                                              if (!isLoggedIn.value) {
                                                await showAuthzPromptDialog(
                                                  context,
                                                  type: AuthzPromptType.signIn,
                                                  onPrimary: () =>
                                                      context.go('/signin'),
                                                );
                                                return;
                                              }
                                              if (isSaved) {
                                                await removeFromMovieBox(
                                                    movie.id);
                                              } else {
                                                await addToMovieBox(movie.id);
                                              }
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              final prompt =
                                                  authzPromptFromError(e);
                                              if (prompt ==
                                                  AuthzPromptType.signIn) {
                                                await showAuthzPromptDialog(
                                                  context,
                                                  type: AuthzPromptType.signIn,
                                                  onPrimary: () =>
                                                      context.go('/signin'),
                                                );
                                                return;
                                              }
                                              if (prompt ==
                                                  AuthzPromptType.buyPlan) {
                                                await showAuthzPromptDialog(
                                                  context,
                                                  type: AuthzPromptType.buyPlan,
                                                  onPrimary: () =>
                                                      context.go('/profile'),
                                                );
                                                return;
                                              }

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(isSaved
                                                      ? 'Failed to remove from MovieBox'
                                                      : 'Failed to save to MovieBox'),
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _PlayButton(onTap: () {
                                        () async {
                                          if (movie.isSeries) {
                                            await _loadEpisodes(movie.id);
                                            final firstEpId =
                                                _firstEpisodeIdFromLoaded();
                                            if (firstEpId != null) {
                                              if (!context.mounted) return;
                                              showDialog(
                                                context: context,
                                                barrierDismissible: true,
                                                builder: (_) =>
                                                    InlinePlayerDialogDemo.episode(
                                                  episodeId: firstEpId,
                                                  title: 'Episode 1',
                                                ),
                                              );
                                              return;
                                            }
                                          }
                                          if (!context.mounted) return;
                                          showDialog(
                                            context: context,
                                            barrierDismissible: true,
                                            builder: (_) => InlinePlayerDialogDemo(
                                                movieId: movie.id),
                                          );
                                        }();
                                      }),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 220,
                                      child: ValueListenableBuilder<Set<int>>(
                                        valueListenable: savedMovieIds,
                                        builder: (context, ids, _) {
                                          final isSaved =
                                              ids.contains(movie.id);
                                          return _AddToListButton(
                                            isSaved: isSaved,
                                            onTap: () async {
                                              try {
                                                if (!isLoggedIn.value) {
                                                  await showAuthzPromptDialog(
                                                    context,
                                                    type: AuthzPromptType.signIn,
                                                    onPrimary: () =>
                                                        context.go('/signin'),
                                                  );
                                                  return;
                                                }
                                                if (isSaved) {
                                                  await removeFromMovieBox(
                                                      movie.id);
                                                } else {
                                                  await addToMovieBox(
                                                      movie.id);
                                                }
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                final prompt =
                                                    authzPromptFromError(e);
                                                if (prompt ==
                                                    AuthzPromptType.signIn) {
                                                  await showAuthzPromptDialog(
                                                    context,
                                                    type:
                                                        AuthzPromptType.signIn,
                                                    onPrimary: () =>
                                                        context.go('/signin'),
                                                  );
                                                  return;
                                                }
                                                if (prompt ==
                                                    AuthzPromptType.buyPlan) {
                                                  await showAuthzPromptDialog(
                                                    context,
                                                    type:
                                                        AuthzPromptType.buyPlan,
                                                    onPrimary: () =>
                                                        context.go('/profile'),
                                                  );
                                                  return;
                                                }

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(isSaved
                                                        ? 'Failed to remove from MovieBox'
                                                        : 'Failed to save to MovieBox'),
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0x22FFFFFF)),
                      const SizedBox(height: 20),
                      // Description
                      const Text(
                        'Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        movie.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Genres
                      const Text(
                        'Genres',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: movie.genres
                            .map((g) => Chip(
                                  label: Text(g),
                                  backgroundColor: Colors.red.withOpacity(0.12),
                                  labelStyle:
                                      const TextStyle(color: Colors.redAccent),
                                  side:
                                      const BorderSide(color: Colors.redAccent),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      // Cast
                      const Text(
                        'Cast',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 132,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: movie.actors.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final actor = movie.actors[index];
                            final canOpen = actor.personId > 0;
                            return InkWell(
                              onTap: canOpen
                                  ? () =>
                                      context.push('/actor/${actor.personId}')
                                  : null,
                              child: SizedBox(
                                width: 110,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border:
                                            Border.all(color: Colors.white24),
                                        color: Colors.grey[850],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        actor.name.isNotEmpty
                                            ? actor.name[0]
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      actor.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      actor.character,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (movie.isSeries) ...[
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Text(
                                'Episodes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Text(
                              'Seasons:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Builder(
                              builder: (context) {
                                final seasons = _episodes
                                    .map((e) =>
                                        (e['seasonNumber'] as num?)?.toInt() ??
                                        (e['season'] as num?)?.toInt() ??
                                        0)
                                    .where((s) => s > 0)
                                    .toSet()
                                    .toList()
                                  ..sort();
                                final selected = (seasons.isNotEmpty)
                                    ? (_selectedSeason != null &&
                                            seasons.contains(_selectedSeason)
                                        ? _selectedSeason
                                        : seasons.first)
                                    : null;
                                if (_selectedSeason != selected) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (!mounted) return;
                                    setState(() {
                                      _selectedSeason = selected;
                                    });
                                  });
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      dropdownColor: Colors.black87,
                                      value: selected,
                                      icon: const Icon(Icons.arrow_drop_down,
                                          color: Colors.redAccent),
                                      items: seasons
                                          .map(
                                            (s) => DropdownMenuItem<int>(
                                              value: s,
                                              child: Text(
                                                'Season $s',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: seasons.isEmpty
                                          ? null
                                          : (v) {
                                              setState(() {
                                                _selectedSeason = v;
                                              });
                                            },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_episodesLoading)
                          const Center(
                            child: SizedBox(
                              height: 28,
                              width: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (_episodesError != null)
                          Text(
                            _episodesError!,
                            style: const TextStyle(color: Colors.white70),
                          )
                        else if (_episodes.isEmpty)
                          const Text(
                            'No episodes available',
                            style: TextStyle(color: Colors.white70),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _episodes.where((e) {
                              final season =
                                  (e['seasonNumber'] as num?)?.toInt() ??
                                      (e['season'] as num?)?.toInt() ??
                                      0;
                              return _selectedSeason == null ||
                                  season == _selectedSeason;
                            }).length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final filtered = _episodes.where((e) {
                                final season =
                                    (e['seasonNumber'] as num?)?.toInt() ??
                                        (e['season'] as num?)?.toInt() ??
                                        0;
                                return _selectedSeason == null ||
                                    season == _selectedSeason;
                              }).toList();
                              final ep = filtered[index];
                              final epId = (ep['episodeID'] as num?)?.toInt() ??
                                  (ep['episodeId'] as num?)?.toInt() ??
                                  (ep['id'] as num?)?.toInt() ??
                                  0;
                              final epTitle =
                                  (ep['title'] as String?)?.trim().isNotEmpty ==
                                          true
                                      ? (ep['title'] as String)
                                      : 'Episode $epId';
                              final seasonNumber =
                                  (ep['seasonNumber'] as num?)?.toInt() ??
                                      (ep['season'] as num?)?.toInt();
                              final episodeNumber =
                                  (ep['episodeNumber'] as num?)?.toInt() ??
                                      (ep['episode'] as num?)?.toInt();
                              final synopsis =
                                  (ep['synopsis'] as String?)?.trim();
                              final description =
                                  (ep['description'] as String?)?.trim() ??
                                      (ep['overview'] as String?)?.trim();
                              final durationSeconds =
                                  (ep['durationSeconds'] as num?)?.toInt();
                              final epLabel = episodeNumber != null
                                  ? 'Episode $episodeNumber'
                                  : (epId > 0 ? 'Episode $epId' : 'Episode');

                              return InkWell(
                                onTap: epId <= 0
                                    ? null
                                    : () {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          builder: (_) =>
                                              InlinePlayerDialogDemo.episode(
                                            episodeId: epId,
                                            title: epTitle,
                                          ),
                                        );
                                      },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 76,
                                            height: 76,
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.red.withOpacity(0.75),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.play_arrow,
                                                color: Colors.white, size: 36),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        epLabel,
                                                        style: const TextStyle(
                                                          color:
                                                              Colors.redAccent,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      durationSeconds != null
                                                          ? '${durationSeconds}s'
                                                          : '—s',
                                                      style: const TextStyle(
                                                          color: Colors.white60,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  epTitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if (synopsis != null &&
                                                    synopsis.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    synopsis,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 13),
                                                  ),
                                                ],
                                                if (description != null &&
                                                    description.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    description,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 13),
                                                  ),
                                                ],
                                                if (seasonNumber != null &&
                                                    episodeNumber != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Season $seasonNumber • Episode $episodeNumber',
                                                    style: const TextStyle(
                                                        color: Colors.white38,
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.chevron_right,
                                              color: Colors.white54),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(color: Color(0x22FFFFFF)),
                      const SizedBox(height: 20),
                      // Rating (logged-in only; plan required to rate)
                      _UserRatingSectionDemo(movieId: movie.id),
                      const SizedBox(height: 20),
                      // Comments (API-driven, replies supported)
                      CommentsDemoWidget(movieId: movie.id),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Small UI helpers
class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.play_arrow, size: 26),
      label: const Text('Play',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}

class _AddToListButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isSaved;
  const _AddToListButton({required this.onTap, required this.isSaved});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(isSaved ? Icons.check : Icons.add),
      label: Text(isSaved ? 'Saved' : 'My List',
          style: const TextStyle(fontSize: 15)),
    );
  }
}

class _UserRatingSectionDemo extends StatefulWidget {
  final int movieId;
  const _UserRatingSectionDemo({required this.movieId});

  @override
  State<_UserRatingSectionDemo> createState() => _UserRatingSectionDemoState();
}

class _UserRatingSectionDemoState extends State<_UserRatingSectionDemo> {
  bool _loading = false;
  bool _submitting = false;
  bool _hasPlan = false;
  int _myStars = 0;
  int? _myUserRatingId;
  double _avg = 0;
  int _count = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _UserRatingSectionDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieId != widget.movieId) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!(isLoggedIn.value == true) || currentUserInfo.value == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final info = currentUserInfo.value ?? {};
      final userIdStr = info['userID'];
      final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
      if (userId == null || userId <= 0) {
        setState(() {
          _loading = false;
        });
        return;
      }

      // Subscription
      bool hasPlan = false;
      try {
        final subsRes = await http.get(
          Uri.parse(
              '${AppConstants.baseApiUrl}/api/payment/subscription/user/$userId'),
          headers: _authHeaders(),
        );
        if (subsRes.statusCode >= 200 && subsRes.statusCode < 300) {
          final body = json.decode(subsRes.body);
          final data = _unwrapResponseData(body);
          final arr = data is List ? data : <dynamic>[];
          if (arr.isNotEmpty) {
            arr.sort((a, b) {
              final aId =
                  (a['subscriptionID'] ?? a['subscriptionId'] ?? 0) as num;
              final bId =
                  (b['subscriptionID'] ?? b['subscriptionId'] ?? 0) as num;
              return bId.compareTo(aId);
            });
            final latest = arr.first as Map;
            final status =
                (latest['status'] ?? 'active').toString().toLowerCase().trim();
            if (status == 'active' || status == 'trialing') {
              hasPlan = true;
            } else if (latest['currentPeriodEnd'] != null) {
              final end =
                  DateTime.tryParse(latest['currentPeriodEnd'].toString());
              if (end != null && end.isAfter(DateTime.now().toUtc()))
                hasPlan = true;
            }
          }
        }
      } catch (_) {}

      // Average rating (requires auth; only logged-in users see section anyway)
      double avg = 0;
      int count = 0;
      try {
        final res = await http.get(
          Uri.parse(
              '${AppConstants.baseApiUrl}/api/UserRating/GetAllUserRatingsByMovieId/${widget.movieId}'),
          headers: _authHeaders(),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = json.decode(res.body);
          final data = _unwrapResponseData(body);
          final list = data is List ? data : <dynamic>[];
          count = list.length;
          if (count > 0) {
            final total = list.fold<int>(0, (sum, item) {
              final m = item as Map;
              final v = m['stars'] ?? m['rating'] ?? m['ratingValue'] ?? 0;
              final s =
                  (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
              return sum + s;
            });
            avg = total / count;
          }
        }
      } catch (_) {}

      // My rating
      int myStars = 0;
      int? myId;
      try {
        final res = await http.get(
          Uri.parse(
              '${AppConstants.baseApiUrl}/api/UserRating/GetAllUserRatingsByUserId/$userId'),
          headers: _authHeaders(),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = json.decode(res.body);
          final data = _unwrapResponseData(body);
          final list = data is List ? data : <dynamic>[];
          final mine = list.cast<dynamic>().whereType<Map>().firstWhere(
                (m) => (m['movieID'] ?? m['movieId'] ?? 0) == widget.movieId,
                orElse: () => {},
              );
          if (mine.isNotEmpty) {
            final idRaw = mine['userRatingID'] ?? mine['userRatingId'];
            myId = (idRaw is num)
                ? idRaw.toInt()
                : int.tryParse(idRaw?.toString() ?? '');
            final v =
                mine['stars'] ?? mine['rating'] ?? mine['ratingValue'] ?? 0;
            myStars = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _hasPlan = hasPlan;
        _avg = avg;
        _count = count;
        _myStars = myStars.clamp(0, 5);
        _myUserRatingId = myId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit(int stars) async {
    if (_submitting) return;

    final info = currentUserInfo.value ?? {};
    final userIdStr = info['userID'];
    final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
    if (userId == null || userId <= 0) {
      await showAuthzPromptDialog(
        context,
        type: AuthzPromptType.signIn,
        onPrimary: () => context.go('/signin'),
      );
      return;
    }

    if (!_hasPlan) {
      await showAuthzPromptDialog(
        context,
        type: AuthzPromptType.buyPlan,
        onPrimary: () => context.go('/profile'),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      http.Response res;
      if ((_myUserRatingId ?? 0) > 0) {
        res = await _httpClient.put(
          Uri.parse(
              '${AppConstants.baseApiUrl}/api/UserRating/UpdateUserRating'),
          headers: _authHeaders(),
          body: json.encode({
            'userRatingID': _myUserRatingId,
            'userID': userId,
            'movieID': widget.movieId,
            'rating': stars,
          }),
        );
      } else {
        res = await _httpClient.post(
          Uri.parse(
              '${AppConstants.baseApiUrl}/api/UserRating/CreateUserRating'),
          headers: _authHeaders(),
          body: json.encode({
            'userID': userId,
            'movieID': widget.movieId,
            'rating': stars,
          }),
        );
      }

      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _load();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rating submitted')));
      } else {
        if (res.statusCode == 401) {
          await showAuthzPromptDialog(
            context,
            type: AuthzPromptType.signIn,
            onPrimary: () => context.go('/signin'),
          );
          return;
        }
        if (res.statusCode == 403) {
          await showAuthzPromptDialog(
            context,
            type: AuthzPromptType.buyPlan,
            onPrimary: () => context.go('/profile'),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to submit rating (HTTP ${res.statusCode})')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = (isLoggedIn.value == true) && currentUserInfo.value != null;
    final disabled = _submitting;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rate this Movie',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else
            Row(
              children: List.generate(5, (i) {
                final idx = i + 1;
                final selected = idx <= _myStars;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: disabled
                        ? null
                        : () async {
                            if (!loggedIn) {
                              await showAuthzPromptDialog(
                                context,
                                type: AuthzPromptType.signIn,
                                onPrimary: () => context.go('/signin'),
                              );
                              return;
                            }
                            if (!_hasPlan) {
                              await showAuthzPromptDialog(
                                context,
                                type: AuthzPromptType.buyPlan,
                                onPrimary: () => context.go('/profile'),
                              );
                              return;
                            }
                            await _submit(idx);
                          },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Icon(
                        selected ? Icons.star : Icons.star_border,
                        color: Colors.white.withOpacity(selected ? 0.9 : 0.35),
                        size: 26,
                      ),
                    ),
                  ),
                );
              }),
            ),
          const SizedBox(height: 10),
          Text(
            !loggedIn
              ? 'Sign in to rate this movie'
              : _hasPlan
                ? 'Tap a star to rate this movie'
                : 'Buy a plan to rate this movie',
            style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          if (_submitting) ...[
            const SizedBox(height: 10),
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// Video Player Screen
class _PlayableSourceDemo {
  final int? id;
  final String url;
  final String? quality;
  final bool isVip;
  final List<Map<String, String>> subtitles;

  _PlayableSourceDemo({
    this.id,
    required this.url,
    this.quality,
    this.isVip = false,
    this.subtitles = const [],
  });
}

class VideoPlayerScreen extends StatefulWidget {
  final Movie movie;

  const VideoPlayerScreen({super.key, required this.movie});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  String? _error;
  List<_PlayableSourceDemo> _sources = [];
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  String _friendlyAuthError(Object e) {
    final prompt = authzPromptFromError(e);
    if (prompt == AuthzPromptType.signIn) return 'Please sign in to continue.';
    if (prompt == AuthzPromptType.buyPlan) return 'Please buy a plan to continue.';
    return 'Failed to load sources: $e';
  }

  Future<void> _loadSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _sources = [];
    });

    final token = StorageService.getUserToken();
    try {
      // Primary: public movie sources by movieId
      final movieSources = await _fetchMovieSources(widget.movie.id);
      if (movieSources.isNotEmpty) {
        setState(() {
          _sources = movieSources;
          _isLoading = false;
        });
        await _setupPlayerForSource(movieSources[0]);
        return;
      }

      setState(() {
        _error = 'No playable sources available.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _setupPlayerForSource(_PlayableSourceDemo s) async {
    try {
      _disposePlayer();
      final uri = Uri.parse(s.url);
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowMuting: true,
        allowFullScreen: true,
      );
      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Playback failed: $e';
      });
    }
  }

  void _disposePlayer() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  Future<List<_PlayableSourceDemo>> _fetchMovieSources(int movieId) async {
    final url = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/MovieSource/GetMovieSourcesByMovieIdPublic/getByMovieId/$movieId');
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final token = StorageService.getUserToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    final res = await _httpClient.get(url, headers: headers);
    if (res.statusCode == 401) {
      throw Exception('HTTP_401');
    }
    if (res.statusCode == 403) {
      throw Exception('HTTP_403');
    }
    if (res.statusCode != 200) {
      final bodyPreview =
          res.body.length > 400 ? res.body.substring(0, 400) : res.body;
      throw Exception('MovieSources HTTP ${res.statusCode}: $bodyPreview');
    }
    final body = jsonDecode(res.body);
    final List<_PlayableSourceDemo> out = [];
    final data = body is Map ? (body['data'] ?? body['Data'] ?? body) : body;
    if (data is List) {
      for (final s in data) {
        if (s is Map) {
          final sourceUrl = s['sourceUrl'] ?? s['url'];
          if (sourceUrl is String && sourceUrl.isNotEmpty) {
            final id = s['movieSourceID'] ?? s['sourceID'] ?? s['id'];
            final quality = s['quality']?.toString();
            final isVip = s['isVipOnly'] == true || s['isVip'] == true;
            out.add(_PlayableSourceDemo(
              id: id is int ? id : int.tryParse('$id'),
              url: sourceUrl,
              quality: quality,
              isVip: isVip,
            ));
          }
        }
      }
    }
    return await _attachSubtitles(out);
  }

  Future<List<_PlayableSourceDemo>> _attachSubtitles(
      List<_PlayableSourceDemo> sources) async {
    final List<_PlayableSourceDemo> result = [];
    for (final s in sources) {
      if (s.id == null) {
        result.add(s);
        continue;
      }
      try {
        final url = Uri.parse(
            '${AppConstants.baseApiUrl}/api/MovieSubTitle/GetAllSubTitlesBySourceID/${s.id}');
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          final subs = <Map<String, String>>[];
          // Unwrap ResponseDto<Data> if present, else accept raw array fallback
          List<dynamic> list = [];
          if (body is Map && body['data'] is List) {
            list = (body['data'] as List);
          } else if (body is List) {
            list = body;
          }
          for (final sub in list) {
            if (sub is Map) {
              final lang = sub['language']?.toString() ??
                  sub['lang']?.toString() ??
                  'Subtitle';
              final subUrl = sub['linkSubTitle']?.toString() ??
                  sub['subtitleUrl']?.toString() ??
                  sub['url']?.toString();
              if (subUrl != null && subUrl.isNotEmpty) {
                subs.add({'lang': lang, 'url': subUrl});
              }
            }
          }
          result.add(_PlayableSourceDemo(
            id: s.id,
            url: s.url,
            quality: s.quality,
            isVip: s.isVip,
            subtitles: subs,
          ));
        } else {
          result.add(s);
        }
      } catch (_) {
        result.add(s);
      }
    }
    return result;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.movie.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.white)))
                : _sources.isEmpty
                    ? const Center(
                        child: Text('No sources available',
                            style: TextStyle(color: Colors.white)))
                    : ListView.separated(
                        itemCount:
                            _sources.length > 1 ? _sources.length + 1 : 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Card(
                              color: Colors.grey[900],
                              child: AspectRatio(
                                aspectRatio:
                                    _videoController?.value.aspectRatio ??
                                        16 / 9,
                                child: _chewieController == null
                                    ? const Center(
                                        child: Text('Select a source to play',
                                            style:
                                                TextStyle(color: Colors.white)))
                                    : Chewie(controller: _chewieController!),
                              ),
                            );
                          }
                          // Only render source cards if there are multiple sources
                          if (_sources.length <= 1) {
                            return const SizedBox.shrink();
                          }
                          final s = _sources[index - 1];
                          return Card(
                            color: Colors.grey[900],
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Source ${s.id ?? index} • ${s.quality ?? 'Auto'}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      if (s.isVip)
                                        const Chip(label: Text('VIP')),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final idx = index - 1;
                                          setState(() {
                                            _currentIndex = idx;
                                          });
                                          await _setupPlayerForSource(s);
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red),
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Play this source'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: s.url));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Source URL copied')),
                                          );
                                        },
                                        icon: const Icon(Icons.link),
                                        label: const Text('Copy URL'),
                                      ),
                                    ],
                                  ),
                                  if (s.subtitles.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Text('Subtitles',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: s.subtitles.map((sub) {
                                        return OutlinedButton(
                                          onPressed: () =>
                                              _openUrl(sub['url']!),
                                          child:
                                              Text(sub['lang'] ?? 'Subtitle'),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }
}

Widget _controlIcon(IconData icon, {double size = 28}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white10,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white24),
    ),
    padding: const EdgeInsets.all(10),
    child: Icon(icon, color: Colors.white, size: size),
  );
}

// Comments widget (demo)
class CommentsDemoWidget extends StatefulWidget {
  final int movieId;
  const CommentsDemoWidget({super.key, required this.movieId});

  @override
  State<CommentsDemoWidget> createState() => _CommentsDemoWidgetState();
}

// Simple inline player dialog for demo
class InlinePlayerDialogDemo extends StatefulWidget {
  final int? movieId;
  final int? episodeId;
  final String title;

  const InlinePlayerDialogDemo({
    super.key,
    required int movieId,
  })  : movieId = movieId,
        episodeId = null,
        title = 'Now Playing';

  const InlinePlayerDialogDemo.episode({
    super.key,
    required int episodeId,
    required this.title,
  })  : episodeId = episodeId,
        movieId = null;

  @override
  State<InlinePlayerDialogDemo> createState() => _InlinePlayerDialogDemoState();
}

class _InlinePlayerDialogDemoState extends State<InlinePlayerDialogDemo>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _useYoutubeEmbed = false;
  String? _youtubeUrl;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  // Subtitles state for demo player
  bool _subsEnabled = false; // off by default
  String? _subtitleLang;
  String? _subtitleUrl;
  List<Subtitle> _subtitleCues = const [];
  bool _isFetchingSubs = false;
  bool _uiVisible = true;
  Timer? _hideTimer;

  // Current source meta with id
  _DemoSource? _currentSource;

  // Simple source holder for demo

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _load();
    _animController.forward();
  }

  String _friendlyAuthError(Object e) {
    final prompt = authzPromptFromError(e);
    if (prompt == AuthzPromptType.signIn) return 'Please sign in to continue.';
    if (prompt == AuthzPromptType.buyPlan) return 'Please buy a plan to continue.';
    return 'Playback failed: $e';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final src = widget.episodeId != null
          ? await _fetchPrimaryEpisodeSource(widget.episodeId!)
          : await _fetchPrimaryMovieSource(widget.movieId!);
      if (src == null) {
        setState(() {
          _error = 'No playable source';
          _loading = false;
        });
        return;
      }
      _currentSource = src;

      if (isYoutubeUrl(src.url)) {
        setState(() {
          _useYoutubeEmbed = true;
          _youtubeUrl = src.url;
          _loading = false;
          _error = null;
        });
        _scheduleHideUI();
        return;
      }

      final vc = VideoPlayerController.networkUrl(Uri.parse(src.url));
      await vc.initialize();
      // Optionally load subtitles for current source if enabled
      await _maybeLoadSubtitlesForCurrent();
      final cc = ChewieController(
        videoPlayerController: vc,
        autoPlay: true,
        showOptions: false,
        // Always provide available cues; Chewie's CC button handles on/off
        subtitle: Subtitles(_subtitleCues),
        subtitleBuilder: (context, subtitle) => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black54,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
        additionalOptions: (context) => [
          OptionItem(
            iconData: Icons.closed_caption,
            title: 'Subtitles',
            onTap: (ctx) async {
              await _pickSubtitleLanguage();
            },
          ),
        ],
      );
      setState(() {
        _videoController = vc;
        _chewieController = cc;
        _useYoutubeEmbed = false;
        _youtubeUrl = null;
        _loading = false;
      });
      _scheduleHideUI();
    } catch (e) {
      final srcUrl = _currentSource?.url;
      if (srcUrl != null && isYoutubeUrl(srcUrl)) {
        setState(() {
          _useYoutubeEmbed = true;
          _youtubeUrl = srcUrl;
          _loading = false;
          _error = null;
        });
        _scheduleHideUI();
        return;
      }
      setState(() {
        _error = _friendlyAuthError(e);
        _loading = false;
      });
    }
  }

  Future<_DemoSource?> _fetchPrimaryMovieSource(int id) async {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/MovieSource/GetMovieSourcesByMovieIdPublic/getByMovieId/$id');
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final token = StorageService.getUserToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    final res = await _httpClient.get(uri, headers: headers);
    if (res.statusCode == 401) {
      throw Exception('HTTP_401');
    }
    if (res.statusCode == 403) {
      throw Exception('HTTP_403');
    }
    if (res.statusCode != 200) {
      final bodyPreview =
          res.body.length > 500 ? res.body.substring(0, 500) : res.body;
      throw Exception('MovieSources HTTP ${res.statusCode}: $bodyPreview');
    }
    final body = jsonDecode(res.body);
    final data = body is Map ? (body['data'] ?? body['Data'] ?? body) : body;
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map) {
        final sourceUrl = first['sourceUrl'] ?? first['url'];
        final id0 = first['movieSourceID'] ?? first['sourceID'] ?? first['id'];
        final sid = id0 is int ? id0 : int.tryParse('$id0');
        if (sid != null && sourceUrl is String && sourceUrl.isNotEmpty) {
          final subs = await _fetchSubtitlesBySourceId(sid, isEpisode: false);
          return _DemoSource(id: sid, url: sourceUrl, subtitles: subs);
        }
      }
    }
    return null;
  }

  Future<_DemoSource?> _fetchPrimaryEpisodeSource(int episodeId) async {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/EpisodeSource/GetEpisodeSourcesByEpisodeId/$episodeId');
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final token = StorageService.getUserToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    final res = await _httpClient.get(uri, headers: headers);
    if (res.statusCode == 401) {
      throw Exception('HTTP_401');
    }
    if (res.statusCode == 403) {
      throw Exception('HTTP_403');
    }
    if (res.statusCode != 200) {
      final bodyPreview =
          res.body.length > 500 ? res.body.substring(0, 500) : res.body;
      throw Exception('EpisodeSources HTTP ${res.statusCode}: $bodyPreview');
    }

    final body = jsonDecode(res.body);
    final data = body is Map ? (body['data'] ?? body['Data'] ?? body) : body;
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map) {
        final sourceUrl = first['sourceUrl'] ?? first['url'];
        final id0 =
            first['episodeSourceID'] ?? first['sourceID'] ?? first['id'];
        final sid = id0 is int ? id0 : int.tryParse('$id0');
        if (sid != null && sourceUrl is String && sourceUrl.isNotEmpty) {
          final subs = await _fetchSubtitlesBySourceId(sid, isEpisode: true);
          return _DemoSource(id: sid, url: sourceUrl, subtitles: subs);
        }
      }
    }
    return null;
  }

  Future<List<Map<String, String>>> _fetchSubtitlesBySourceId(
    int sourceId, {
    required bool isEpisode,
  }) async {
    try {
      final url = Uri.parse(isEpisode
          ? '${AppConstants.baseApiUrl}/api/MovieSubTitle/GetAllSubTitlesByEpisodeId/episode/GetAllSubTitlesBySourceID/$sourceId'
          : '${AppConstants.baseApiUrl}/api/MovieSubTitle/GetAllSubTitlesByMovieId/movie/GetAllSubTitlesBySourceID/$sourceId');
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      final token = StorageService.getUserToken();
      if (token != null && token.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${token.trim()}';
      }

      final res = await http.get(url, headers: headers);
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      List<dynamic> list = [];
      if (body is Map && (body['data'] is List || body['Data'] is List)) {
        list = (body['data'] as List?) ?? (body['Data'] as List?) ?? [];
      } else if (body is List) {
        list = body;
      }
      final subs = <Map<String, String>>[];
      for (final sub in list) {
        if (sub is Map) {
          final lang = sub['language']?.toString() ??
              sub['lang']?.toString() ??
              'Subtitle';
          final subUrl = sub['linkSubTitle']?.toString() ??
              sub['subtitleUrl']?.toString() ??
              sub['url']?.toString();
          final idVal = sub['movieSubTitleID'] ??
              sub['MovieSubTitleID'] ??
              sub['subTitleID'] ??
              sub['id'];
          if (subUrl != null && subUrl.isNotEmpty) {
            subs.add({
              'lang': lang,
              'url': subUrl,
              if (idVal != null) 'id': idVal.toString(),
            });
          }
        }
      }
      return subs;
    } catch (_) {
      return [];
    }
  }

  Future<void> _maybeLoadSubtitlesForCurrent() async {
    if (_currentSource == null) {
      _subtitleCues = const [];
      return;
    }
    final subs = _currentSource!.subtitles;
    if (subs.isEmpty) {
      _subtitleCues = const [];
      return;
    }
    Map<String, String>? chosen;
    if (_subtitleUrl != null) {
      chosen = subs.firstWhere((e) => e['url'] == _subtitleUrl,
          orElse: () => subs.first);
    } else if (_subtitleLang != null) {
      chosen = subs.firstWhere(
        (e) => (e['lang'] ?? '').toLowerCase() == _subtitleLang!.toLowerCase(),
        orElse: () => subs.first,
      );
    } else {
      // Prefer movieSubTitleID == 7 (English), then any English, else first
      chosen = subs.firstWhere(
        (e) {
          final idStr = e['id'];
          final id = idStr != null ? int.tryParse(idStr) : null;
          return id == 7;
        },
        orElse: () {
          try {
            return subs.firstWhere(
                (e) => (e['lang'] ?? '').toLowerCase().startsWith('en'));
          } catch (_) {
            return subs.first;
          }
        },
      );
    }
    if (chosen == null) {
      _subtitleCues = const [];
      return;
    }

    final url = chosen['url'];
    if (url == null || url.isEmpty) {
      _subtitleCues = const [];
      return;
    }
    _subtitleLang = chosen['lang'];
    _subtitleUrl = url;
    _isFetchingSubs = true;
    try {
      final subtitleUri = Uri.parse(url);
      final token = StorageService.getUserToken();
      final needsAuth = token != null &&
          token.trim().isNotEmpty &&
          url.startsWith(AppConstants.baseApiUrl);
      final res = await http.get(
        subtitleUri,
        headers:
            needsAuth ? {'Authorization': 'Bearer ${token!.trim()}'} : null,
      );
      if (res.statusCode == 200) {
        _subtitleCues = _parseSrtOrVttToChewie(res.body);
        if (_subtitleCues.isNotEmpty) {
          final first = _subtitleCues.first;
          final last = _subtitleCues.last;
          // Basic diagnostics to verify parsing in web console
          // ignore: avoid_print
          print('Subtitles loaded: ${_subtitleCues.length} cues from ' + url);
          // ignore: avoid_print
          print('First cue: ${first.start} -> ${first.end}');
          // ignore: avoid_print
          print('Last cue: ${last.start} -> ${last.end}');
        } else {
          // ignore: avoid_print
          print('Subtitles parse produced 0 cues for ' + url);
        }
      } else {
        _subtitleCues = const [];
      }
    } catch (_) {
      _subtitleCues = const [];
    } finally {
      _isFetchingSubs = false;
    }
  }

  List<Subtitle> _parseSrtOrVttToChewie(String content) {
    final cleaned = content.replaceAll('\ufeff', '').replaceAll('\r', '');
    final lines = cleaned.split('\n');
    if (lines.isNotEmpty &&
        lines.first.trim().toUpperCase().startsWith('WEBVTT')) {
      lines.removeAt(0);
      // Skip optional header separator
      if (lines.isNotEmpty && lines.first.trim().isEmpty) {
        lines.removeAt(0);
      }
    }

    final timeRegex = RegExp(
        r'(?<start>\d{2}:\d{2}:\d{2}[\.,]\d{3})\s*-->\s*(?<end>\d{2}:\d{2}:\d{2}[\.,]\d{3})');

    final cues = <Subtitle>[];
    int i = 0;
    // Primary pass: SRT-style blocks
    while (i < lines.length) {
      // Skip sequence number if present
      if (RegExp(r'^\d+$').hasMatch(lines[i].trim())) {
        i++;
      }
      if (i >= lines.length) break;
      final timeLine = lines[i].trim();
      final timeMatch = timeRegex.firstMatch(timeLine);
      if (timeMatch == null) {
        i++;
        continue;
      }
      final startStr = timeMatch.namedGroup('start')!;
      final endStr = timeMatch.namedGroup('end')!;
      i++;
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        textLines.add(lines[i]);
        i++;
      }
      // Skip blank line(s)
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      final start = _parseTimestamp(startStr);
      final end = _parseTimestamp(endStr);
      if (start != null && end != null) {
        cues.add(Subtitle(
          index: cues.length,
          start: start,
          end: end,
          text: textLines.join('\n'),
        ));
      }
    }

    // Fallback pass: continuous VTT/SRT without blank separators
    if (cues.length <= 1) {
      final fallbackCues = <Subtitle>[];
      int j = 0;
      while (j < lines.length) {
        final match = timeRegex.firstMatch(lines[j].trim());
        if (match == null) {
          j++;
          continue;
        }
        final startStr = match.namedGroup('start')!;
        final endStr = match.namedGroup('end')!;
        j++;
        final textLines = <String>[];
        while (j < lines.length && !timeRegex.hasMatch(lines[j].trim())) {
          if (lines[j].trim().isEmpty && textLines.isNotEmpty) break;
          textLines.add(lines[j]);
          j++;
        }
        final start = _parseTimestamp(startStr);
        final end = _parseTimestamp(endStr);
        if (start != null && end != null) {
          fallbackCues.add(Subtitle(
            index: fallbackCues.length,
            start: start,
            end: end,
            text: textLines.join('\n'),
          ));
        }
        // Skip blank line between cues if present
        while (j < lines.length && lines[j].trim().isEmpty) {
          j++;
        }
      }
      if (fallbackCues.isNotEmpty) {
        return fallbackCues;
      }
    }

    return cues;
  }

  Duration? _parseTimestamp(String s) {
    final normalized = s.replaceAll(',', '.');
    final parts = normalized.split('.');
    final main = parts[0];
    final msStr = parts.length > 1 ? parts[1] : '000';
    final hms = main.split(':');
    if (hms.length != 3) return null;
    final h = int.tryParse(hms[0]) ?? 0;
    final m = int.tryParse(hms[1]) ?? 0;
    final sec = int.tryParse(hms[2]) ?? 0;
    final ms = int.tryParse(msStr.padRight(3, '0').substring(0, 3)) ?? 0;
    return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
  }

  Future<void> _toggleSubs() async {
    setState(() {
      _subsEnabled = !_subsEnabled;
    });
    await _reloadChewieWithSubs();
  }

  Future<void> _reloadChewieWithSubs() async {
    if (_videoController == null) return;
    await _maybeLoadSubtitlesForCurrent();
    _chewieController?.dispose();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      showOptions: false,
      // Always provide cues; Chewie manages visibility via its CC toggle
      subtitle: Subtitles(_subtitleCues),
      subtitleBuilder: (context, subtitle) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black54,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
      additionalOptions: (context) => [
        OptionItem(
          iconData: Icons.closed_caption,
          title: 'Subtitles',
          onTap: (ctx) async {
            await _pickSubtitleLanguage();
          },
        ),
      ],
    );
    setState(() {
      _uiVisible = true;
    });
    _scheduleHideUI();
  }

  void _scheduleHideUI() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _uiVisible = false;
        });
      }
    });
  }

  void _showUI() {
    if (!_uiVisible) {
      setState(() {
        _uiVisible = true;
      });
    }
    _scheduleHideUI();
  }

  Future<void> _showSpeedMenu() async {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final choice = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Select Playback Speed')),
            ...speeds.map((s) => ListTile(
                  leading: const Icon(Icons.speed),
                  title: Text('${s}x'),
                  onTap: () => Navigator.of(ctx).pop(s),
                )),
          ],
        );
      },
    );
    if (choice != null) {
      await _videoController?.setPlaybackSpeed(choice);
    }
  }

  Future<void> _pickSubtitleLanguage() async {
    final s = _currentSource;
    if (s == null || s.subtitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subtitles available')));
      return;
    }
    final size = MediaQuery.of(context).size;
    // Anchor dropdown near bottom-left of the player/dialog
    final position = RelativeRect.fromLTRB(
      16,
      size.height - 260,
      0,
      16,
    );
    final choice = await showMenu<Map<String, String>>(
      context: context,
      position: position,
      items: [
        for (final sub in s.subtitles)
          PopupMenuItem<Map<String, String>>(
            value: sub,
            child: Text(sub['lang'] ?? 'Subtitle'),
          ),
      ],
      color: Colors.black87,
    );
    if (choice != null) {
      setState(() {
        _subtitleLang = choice['lang'];
        _subtitleUrl = choice['url'];
      });
      await _reloadChewieWithSubs();
      if (_subtitleCues.isNotEmpty) {
        final first = _subtitleCues.first.start;
        try {
          await _videoController?.seekTo(first);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.title,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                MouseRegion(
                  onHover: (_) => _showUI(),
                  child: GestureDetector(
                    onTap: _showUI,
                    child: AspectRatio(
                      aspectRatio:
                          _videoController?.value.aspectRatio ?? 16 / 9,
                      child: Stack(
                        children: [
                          _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _error != null
                                  ? Center(
                                      child: Text(_error!,
                                          style: const TextStyle(
                                              color: Colors.white70)))
                                  : (_useYoutubeEmbed && _youtubeUrl != null)
                                      ? Positioned.fill(
                                          child: YoutubeEmbedPlayer(
                                              url: _youtubeUrl!),
                                        )
                                      : (_chewieController != null
                                          ? Chewie(
                                              controller: _chewieController!)
                                          : const SizedBox.shrink()),
                          // Custom dropdown settings (playback speed + subtitles)
                          if (!(_useYoutubeEmbed && _youtubeUrl != null) &&
                              (_uiVisible ||
                                  (_chewieController?.isFullScreen ?? false)))
                            Positioned(
                              right: 88,
                              bottom: 8,
                              child: PopupMenuButton<String>(
                                tooltip: 'Settings',
                                color: Colors.black87,
                                icon: const Icon(Icons.settings,
                                    color: Colors.white),
                                offset: const Offset(0, -8),
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'speed':
                                      await _showSpeedMenu();
                                      break;
                                    case 'subs':
                                      await _pickSubtitleLanguage();
                                      break;
                                  }
                                },
                                itemBuilder: (ctx) => const [
                                  PopupMenuItem(
                                    value: 'speed',
                                    child: Row(
                                      children: [
                                        Icon(Icons.speed,
                                            color: Colors.white70),
                                        SizedBox(width: 8),
                                        Text('Playback speed',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'subs',
                                    child: Row(
                                      children: [
                                        Icon(Icons.closed_caption,
                                            color: Colors.white70),
                                        SizedBox(width: 8),
                                        Text('Subtitles',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // CC debug overlay removed
                          // Removed custom CC toggle; rely on Chewie's built-in CC icon
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsDemoWidgetState extends State<CommentsDemoWidget> {
  List<CommentDemo> _comments = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _composer = TextEditingController();
  int? _replyingTo;
  bool _posting = false;

  final Map<int, _UserSlimLite> _userCache = <int, _UserSlimLite>{};
  final Set<int> _fetchingUsers = <int>{};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
          '${AppConstants.baseApiUrl}/api/Comment/GetCommentsByMovieID/${widget.movieId}');
      final res = await _httpClient.get(uri, headers: _authHeaders());
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = _unwrapResponseData(body);
        final raw = data is List ? data : const [];
        final list = <CommentDemo>[];
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            list.add(CommentDemo.fromJson(e));
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _comments = list;
          _loading = false;
        });

        unawaited(_prefetchUsersForComments(list));
      } else if (res.statusCode == 401) {
        setState(() {
          _error = 'Please sign in to view comments';
          _loading = false;
        });
      } else if (res.statusCode == 403) {
        setState(() {
          _error = 'Please buy a plan to view comments';
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch comments (HTTP ${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _prefetchUsersForComments(List<CommentDemo> list) async {
    if (!mounted) return;
    if (!isLoggedIn.value) return;

    final info = currentUserInfo.value;
    final meId = int.tryParse((info?['userID'] ?? info?['userId'] ?? '').toString());

    final ids = list
        .map((c) => c.userID)
        .where((id) => id > 0 && id != meId)
        .toSet();
    final missing = ids.where((id) => !_userCache.containsKey(id) && !_fetchingUsers.contains(id)).toList();
    if (missing.isEmpty) return;

    for (final id in missing) {
      _fetchingUsers.add(id);
    }

    try {
      // Limit concurrency to avoid spamming the backend.
      int index = 0;
      Future<void> worker() async {
        while (index < missing.length) {
          final userId = missing[index++];
          try {
            final data = await UserService().getUserSlimById(userId);
            final profile = (data['profile'] is Map)
                ? Map<String, dynamic>.from(data['profile'] as Map)
                : null;
            final userName = (data['userName'] ?? data['UserName'] ?? data['name'] ?? '').toString();
            final avatar = (data['avatar'] ?? profile?['avatar'])?.toString();
            if (mounted) {
              setState(() {
                _userCache[userId] = _UserSlimLite(
                  userId: userId,
                  userName: userName.isEmpty ? 'User' : userName,
                  avatar: (avatar != null && avatar.isNotEmpty) ? avatar : null,
                );
              });
            }
          } catch (_) {
            // ignore
          } finally {
            _fetchingUsers.remove(userId);
          }
        }
      }

      await Future.wait(List.generate(6, (_) => worker()));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _post({required String text, int? parentId}) async {
    final info = currentUserInfo.value;
    final logged = isLoggedIn.value;
    if (!logged || info == null) {
      await showAuthzPromptDialog(
        context,
        type: AuthzPromptType.signIn,
        onPrimary: () => context.go('/signin'),
      );
      return;
    }
    final userIdStr = info['userID'];
    final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing user ID; re-sign in')));
      return;
    }
    if (text.trim().isEmpty) return;

    setState(() {
      _posting = true;
    });
    try {
      final uri =
          Uri.parse('${AppConstants.baseApiUrl}/api/Comment/CreateComment');
      final body = jsonEncode({
        'movieID': widget.movieId,
        'userID': userId,
        'content': text.trim(),
        if (parentId != null) 'parentID': parentId,
      });
      final headers = _authHeaders();
      headers['Content-Type'] = 'application/json';
      final res = await _httpClient.post(uri, headers: headers, body: body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _composer.clear();
        setState(() {
          _replyingTo = null;
        });
        await _loadComments();
      } else if (res.statusCode == 401) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.signIn,
          onPrimary: () => context.go('/signin'),
        );
      } else if (res.statusCode == 403) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.buyPlan,
          onPrimary: () => context.go('/profile'),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to post comment')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      setState(() {
        _posting = false;
      });
    }
  }

  Future<void> _editComment(CommentDemo c) async {
    final ctrl = TextEditingController(text: c.content);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Edit comment', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white10,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final newText = result?.trim();
    if (newText == null || newText.isEmpty || newText == c.content) return;

    try {
      final uri = Uri.parse('${AppConstants.baseApiUrl}/api/Comment/UpdateComment');
      final headers = _authHeaders();
      headers['Content-Type'] = 'application/json';

      final res = await _httpClient.put(
        uri,
        headers: headers,
        body: jsonEncode({
          'commentID': c.commentID,
          'movieID': c.movieID,
          'userID': c.userID,
          'parentID': c.parentID,
          'content': newText,
          'likeCount': c.likeCount ?? 0,
        }),
      );

      if (res.statusCode == 401) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.signIn,
          onPrimary: () => context.go('/signin'),
        );
        return;
      }
      if (res.statusCode == 403) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.buyPlan,
          onPrimary: () => context.go('/profile'),
        );
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update comment (HTTP ${res.statusCode})')),
        );
        return;
      }

      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _deleteComment(CommentDemo c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete comment', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final uri = Uri.parse('${AppConstants.baseApiUrl}/api/Comment/DeleteComment/${c.commentID}');
      final res = await _httpClient.delete(uri, headers: _authHeaders());

      if (res.statusCode == 401) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.signIn,
          onPrimary: () => context.go('/signin'),
        );
        return;
      }
      if (res.statusCode == 403) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.buyPlan,
          onPrimary: () => context.go('/profile'),
        );
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment (HTTP ${res.statusCode})')),
        );
        return;
      }

      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _buildComposer(),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
              child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.white70))
        else if (_comments.isEmpty)
          const Text('No comments yet', style: TextStyle(color: Colors.white70))
        else
          _buildCommentsList(),
      ],
    );
  }

  Widget _buildComposer() {
    final info = currentUserInfo.value;
    final avatarUrl = cacheBustUrl(
      resolveApiUrl(info?['avatar']),
      cacheKey: avatarCacheBuster.value,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isNotEmpty
              ? null
              : const Icon(Icons.person, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: isLoggedIn.value
                      ? 'Write a comment...'
                      : 'Sign in to comment',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: const OutlineInputBorder(),
                ),
                enabled: !_posting,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed:
                      _posting ? null : () => _post(text: _composer.text),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: _posting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Post Comment'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    final grouped = _groupComments(_comments);
    final parents = grouped.parents;
    final replies = grouped.repliesByParent;
    return Column(
      children: [
        Row(
          children: [
            Text('${_comments.length} comments',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 8),
        ...parents
            .map((c) => _buildCommentItem(c, replies[c.commentID] ?? const [])),
      ],
    );
  }

  Widget _buildCommentItem(CommentDemo c, List<CommentDemo> replies) {
    final info = currentUserInfo.value;
    final meId = int.tryParse((info?['userID'] ?? info?['userId'] ?? '').toString());
    final isMe = meId != null && c.userID == meId;
    final other = _userCache[c.userID];
    final displayName = isMe
        ? (info?['userName'] ?? '')
        : ((other?.userName.isNotEmpty == true)
            ? other!.userName
            : (c.userName ?? ''));
    final avatarUrl = isMe
        ? cacheBustUrl(
            resolveApiUrl(info?['avatar']),
            cacheKey: avatarCacheBuster.value,
          )
        : resolveApiUrl(other?.avatar);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isNotEmpty
                    ? null
                    : Text(
                        ((displayName.isNotEmpty ? displayName[0] : 'U')).toUpperCase(),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(displayName.isNotEmpty ? displayName : 'User',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(_formatDate(c.createdAt),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        const Spacer(),
                        if (isMe)
                          PopupMenuButton<String>(
                            tooltip: 'More',
                            color: Colors.black87,
                            icon: const Icon(Icons.more_vert, color: Colors.white70, size: 18),
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _editComment(c);
                                  break;
                                case 'delete':
                                  _deleteComment(c);
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.white70, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.content,
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _replyingTo = c.commentID),
                          child: const Text('Reply'),
                        ),
                      ],
                    ),
                    if (_replyingTo == c.commentID)
                      _buildReplyComposer(parentId: c.commentID),
                    if (replies.isNotEmpty) _buildRepliesList(replies),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyComposer({required int parentId}) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _posting
                ? null
                : () async {
                    await _post(text: ctrl.text, parentId: parentId);
                    setState(() => _replyingTo = null);
                  },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesList(List<CommentDemo> replies) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 24),
      child: Column(
        children: replies.map((r) {
          final info = currentUserInfo.value;
          final meId = int.tryParse((info?['userID'] ?? info?['userId'] ?? '').toString());
          final isMe = meId != null && r.userID == meId;
          final other = _userCache[r.userID];
          final displayName = isMe
              ? (info?['userName'] ?? '')
              : ((other?.userName.isNotEmpty == true)
                  ? other!.userName
                  : (r.userName ?? ''));
          final avatarUrl = isMe
              ? cacheBustUrl(
                  resolveApiUrl(info?['avatar']),
                  cacheKey: avatarCacheBuster.value,
                )
              : resolveApiUrl(other?.avatar);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isNotEmpty
                    ? null
                    : Text(
                        ((displayName.isNotEmpty ? displayName[0] : 'U')).toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(displayName.isNotEmpty ? displayName : 'User',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(_formatDate(r.createdAt),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        const Spacer(),
                        if (isMe)
                          PopupMenuButton<String>(
                            tooltip: 'More',
                            color: Colors.black87,
                            icon: const Icon(Icons.more_vert, color: Colors.white70, size: 16),
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _editComment(r);
                                  break;
                                case 'delete':
                                  _deleteComment(r);
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.white70, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r.content,
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  GroupedCommentsDemo _groupComments(List<CommentDemo> all) {
    final parents =
        all.where((c) => c.parentID == null || c.parentID == 0).toList();
    final repliesList =
        all.where((c) => c.parentID != null && c.parentID != 0).toList();
    final Map<int, List<CommentDemo>> repliesByParent = {};
    for (final r in repliesList) {
      final key = r.parentID!;
      repliesByParent.putIfAbsent(key, () => []);
      repliesByParent[key]!.add(r);
    }
    parents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final entry in repliesByParent.entries) {
      entry.value.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return GroupedCommentsDemo(parents, repliesByParent);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// Profile Screen
enum _MovieBoxSort { dateAdded, title, rating }

class MovieBoxScreen extends StatefulWidget {
  const MovieBoxScreen({super.key});

  @override
  State<MovieBoxScreen> createState() => _MovieBoxScreenState();
}

class _MovieBoxScreenState extends State<MovieBoxScreen> {
  _MovieBoxSort _sort = _MovieBoxSort.dateAdded;
  final Map<int, Movie> _cache = <int, Movie>{};
  final Set<int> _loading = <int>{};

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    savedMovieIds.addListener(_handleSavedIdsChanged);
  }

  @override
  void dispose() {
    savedMovieIds.removeListener(_handleSavedIdsChanged);
    super.dispose();
  }

  void _handleSavedIdsChanged() {
    if (!mounted) return;
    unawaited(_ensureLoaded(savedMovieIds.value));
  }

  Future<void> _refresh() async {
    await _ensureCurrentUserFromCookiesIfNeeded();
    await refreshSavedMoviesForCurrentUser();
    await _ensureLoaded(savedMovieIds.value);
  }

  Future<void> _ensureLoaded(Set<int> ids) async {
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();
    if (missing.isEmpty) {
      setState(() {
        _cache.removeWhere((key, _) => !ids.contains(key));
      });
      return;
    }

    for (final id in missing) {
      if (_loading.contains(id)) continue;
      _loading.add(id);
      unawaited(_loadOne(id));
    }
  }

  Future<void> _loadOne(int movieId) async {
    try {
      Movie? fromApp;
      for (final m in appMovies) {
        if (m.id == movieId) {
          fromApp = m;
          break;
        }
      }
      final movie = fromApp ?? await _fetchBasicMovieByIdForMovieBox(movieId);
      if (!mounted) return;
      setState(() {
        _cache[movieId] = movie;
        _loading.remove(movieId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading.remove(movieId);
      });
    }
  }

  List<int> _sortedIds(Set<int> ids) {
    final list = ids.toList();
    list.sort((a, b) {
      final ma = _cache[a];
      final mb = _cache[b];
      switch (_sort) {
        case _MovieBoxSort.title:
          return (ma?.title ?? '').toLowerCase().compareTo(
                (mb?.title ?? '').toLowerCase(),
              );
        case _MovieBoxSort.rating:
          return (mb?.popularity ?? 0).compareTo(ma?.popularity ?? 0);
        case _MovieBoxSort.dateAdded:
          final da = savedMovieCreatedAtMap.value[a];
          final db = savedMovieCreatedAtMap.value[b];
          return (db ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(da ?? DateTime.fromMillisecondsSinceEpoch(0));
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MovieBox'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ValueListenableBuilder<Set<int>>(
        valueListenable: savedMovieIds,
        builder: (context, ids, _) {
          final sorted = _sortedIds(ids);
          if (sorted.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bookmark_border,
                          size: 84, color: Colors.white24),
                      const SizedBox(height: 14),
                      const Text(
                        'Your MovieBox is empty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Save movies to watch later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => context.go('/'),
                          child: const Text('Browse Movies'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Text(
                        '${sorted.length} movies saved',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Date Added'),
                        selected: _sort == _MovieBoxSort.dateAdded,
                        onSelected: (_) => setState(
                            () => _sort = _MovieBoxSort.dateAdded),
                      ),
                      ChoiceChip(
                        label: const Text('Movie Title'),
                        selected: _sort == _MovieBoxSort.title,
                        onSelected: (_) =>
                            setState(() => _sort = _MovieBoxSort.title),
                      ),
                      ChoiceChip(
                        label: const Text('Rating'),
                        selected: _sort == _MovieBoxSort.rating,
                        onSelected: (_) =>
                            setState(() => _sort = _MovieBoxSort.rating),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final crossAxisCount =
                          w < 560 ? 2 : (w < 900 ? 3 : (w < 1200 ? 4 : 5));
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sorted.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.66,
                        ),
                        itemBuilder: (context, index) {
                          final id = sorted[index];
                          final movie = _cache[id];
                          return _MovieBoxCard(
                            movieId: id,
                            movie: movie,
                            onOpen: () => context.go('/movie/$id'),
                            onRemove: () async {
                              try {
                                await removeFromMovieBox(id);
                              } catch (e) {
                                if (!context.mounted) return;
                                final prompt = authzPromptFromError(e);
                                if (prompt == AuthzPromptType.signIn) {
                                  await showAuthzPromptDialog(
                                    context,
                                    type: AuthzPromptType.signIn,
                                    onPrimary: () => context.go('/signin'),
                                  );
                                  return;
                                }
                                if (prompt == AuthzPromptType.buyPlan) {
                                  await showAuthzPromptDialog(
                                    context,
                                    type: AuthzPromptType.buyPlan,
                                    onPrimary: () => context.go('/profile'),
                                  );
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Failed to remove movie')),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MovieBoxCard extends StatelessWidget {
  final int movieId;
  final Movie? movie;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _MovieBoxCard({
    required this.movieId,
    required this.movie,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = movie?.title ?? 'Loading…';
    final year = movie?.year ?? '—';
    final imageUrl = movie?.imageUrl;
    final score = movie?.popularity;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                          child:
                              Icon(Icons.broken_image, color: Colors.white24))),
                )
              else
                Container(color: Colors.grey[900]),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: InkResponse(
                  onTap: onRemove,
                  radius: 18,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
              if (score != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          score.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      year,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Log out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await AuthService().signOut();
              } catch (_) {
                // Ignore server logout failures; still clear local state.
              }
              await StorageService.clearUser();
              isLoggedIn.value = false;
              currentUserInfo.value = null;
              unawaited(refreshSavedMoviesForCurrentUser());
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Logged out')));
                context.go('/');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final info = currentUserInfo.value ?? {};
    final userId = int.tryParse(info['userID'] ?? '');
    if (userId == null || userId <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    final userService = UserService();

    final usernameCtrl = TextEditingController(text: info['userName'] ?? '');
    final firstNameCtrl = TextEditingController(text: info['firstName'] ?? '');
    final lastNameCtrl = TextEditingController(text: info['lastName'] ?? '');

    String gender = (info['gender'] ?? 'other').toString().toLowerCase();
    if (!['male', 'female', 'other'].contains(gender)) gender = 'other';

    DateTime? dateOfBirth = DateTime.tryParse(info['dateOfBirth'] ?? '');
    XFile? avatarFile;
    Uint8List? avatarBytes;

    bool saving = false;
    String? error;

    Future<void> pickAvatar(void Function(void Function()) setState) async {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        avatarFile = file;
        avatarBytes = bytes;
      });
    }

    Future<void> pickDob(void Function(void Function()) setState, BuildContext ctx) async {
      final now = DateTime.now();
      final initial = dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
      final picked = await showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: now,
      );
      if (picked == null) return;
      setState(() => dateOfBirth = picked);
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) {
          final avatarUrl = cacheBustUrl(
            resolveApiUrl(info['avatar']),
            cacheKey: avatarCacheBuster.value,
          );
          final hasNetworkAvatar = avatarBytes == null && avatarUrl.isNotEmpty;
          final dobLabel = dateOfBirth == null
              ? 'Not set'
              : DateFormat('yyyy-MM-dd').format(dateOfBirth!);

          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.red,
                        backgroundImage: avatarBytes != null
                            ? MemoryImage(avatarBytes!)
                            : (hasNetworkAvatar ? NetworkImage(avatarUrl) : null)
                                as ImageProvider<Object>?,
                        child: (avatarBytes == null && !hasNetworkAvatar)
                            ? Text(
                                (usernameCtrl.text.isNotEmpty
                                        ? usernameCtrl.text[0].toUpperCase()
                                        : 'U'),
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: saving ? null : () => pickAvatar(setState),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Change Photo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstNameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'First name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lastNameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Last name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: gender,
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: saving ? null : (v) => setState(() => gender = v ?? 'other'),
                    dropdownColor: Colors.black,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Gender'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Date of birth: $dobLabel',
                            style: const TextStyle(color: Colors.white70)),
                      ),
                      OutlinedButton(
                        onPressed: saving ? null : () => pickDob(setState, dialogCtx),
                        child: const Text('Pick'),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final newUsername = usernameCtrl.text.trim();
                        final firstName = firstNameCtrl.text.trim();
                        final lastName = lastNameCtrl.text.trim();

                        if (newUsername.isEmpty) {
                          setState(() => error = 'Username is required');
                          return;
                        }

                        setState(() {
                          saving = true;
                          error = null;
                        });

                        try {
                          final oldUsername = (info['userName'] ?? '').toString();
                          if (oldUsername.isNotEmpty && newUsername != oldUsername) {
                            await userService.updateUsername(
                              userId: userId,
                              newUsername: newUsername,
                            );
                          }

                          final shouldUpdateProfile =
                              avatarFile != null ||
                              firstName != (info['firstName'] ?? '').toString() ||
                              lastName != (info['lastName'] ?? '').toString() ||
                              gender != (info['gender'] ?? 'other').toString().toLowerCase() ||
                              (dateOfBirth?.toIso8601String() != DateTime.tryParse(info['dateOfBirth'] ?? '')?.toIso8601String());

                          if (shouldUpdateProfile) {
                            await userService.updateProfileMultipart(
                              userId: userId,
                              newUserName: newUsername,
                              firstName: firstName,
                              lastName: lastName,
                              gender: gender,
                              dateOfBirth: dateOfBirth,
                              avatar: avatarFile,
                            );
                          }

                          // Refresh from /user/me
                          try {
                            final me = await userService.getMe();
                            final profile = (me['profile'] is Map)
                                ? Map<String, dynamic>.from(me['profile'] as Map)
                                : <String, dynamic>{};
                            final meUserName = (me['userName'] ?? '').toString();
                            final meEmail = (me['email'] ?? '').toString();
                            final meId = (me['userID'] ?? me['userId'] ?? '').toString();
                            currentUserInfo.value = {
                              'userName': meUserName.isNotEmpty ? meUserName : newUsername,
                              'email': meEmail.isNotEmpty ? meEmail : (info['email'] ?? '').toString(),
                              if (meId.isNotEmpty) 'userID': meId,
                              'firstName': (me['firstName'] ?? profile['firstName'] ?? firstName).toString(),
                              'lastName': (me['lastName'] ?? profile['lastName'] ?? lastName).toString(),
                              if (((me['avatar'] ?? profile['avatar'])?.toString() ?? '').isNotEmpty)
                                'avatar': (me['avatar'] ?? profile['avatar']).toString(),
                              if (((me['gender'] ?? profile['gender'])?.toString() ?? '').isNotEmpty)
                                'gender': (me['gender'] ?? profile['gender']).toString(),
                              if (((me['dateOfBirth'] ?? profile['dateOfBirth'])?.toString() ?? '').isNotEmpty)
                                'dateOfBirth': (me['dateOfBirth'] ?? profile['dateOfBirth']).toString(),
                            };
                            isLoggedIn.value = true;
                          } catch (_) {
                            currentUserInfo.value = {
                              ...info.map((k, v) => MapEntry(k, v?.toString() ?? '')),
                              'userName': newUsername,
                              'firstName': firstName,
                              'lastName': lastName,
                              'gender': gender,
                              if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
                            };
                          }

                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile updated')));
                        } catch (e) {
                          setState(() => error = e.toString());
                        } finally {
                          setState(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: [
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Settings'),
              Tab(text: 'Subscription'),
            ],
          ),
        ),
        body: ValueListenableBuilder<Map<String, String>?>(
          valueListenable: currentUserInfo,
          builder: (context, info, _) {
            final name = info?['userName'] ?? 'Guest';
            final gender = info?['gender'] ?? '—';
            final avatarUrl = cacheBustUrl(
              resolveApiUrl(info?['avatar']),
              cacheKey: avatarCacheBuster.value,
            );

            String dash(String? v) {
              final s = (v ?? '').trim();
              return s.isEmpty ? '—' : s;
            }

            String formatDob(String? raw) {
              final dt = DateTime.tryParse((raw ?? '').trim());
              if (dt == null) return '—';
              return DateFormat('dd/MM/yyyy').format(dt.toLocal());
            }

            return TabBarView(
              children: [
                // Overview
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Card(
                          color: Colors.grey[900],
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.red,
                                      backgroundImage:
                                          avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                      child: avatarUrl.isNotEmpty
                                          ? null
                                          : Text(
                                              (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Username',
                                              style: TextStyle(color: Colors.white70)),
                                          const SizedBox(height: 6),
                                          Text(
                                            dash(info?['userName']),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('First name',
                                              style: TextStyle(color: Colors.white70)),
                                          const SizedBox(height: 6),
                                          Text(
                                            dash(info?['firstName']),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Last name',
                                              style: TextStyle(color: Colors.white70)),
                                          const SizedBox(height: 6),
                                          Text(
                                            dash(info?['lastName']),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text('Gender',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 6),
                                Text(
                                  dash(gender),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text('Date of birth',
                                    style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 6),
                                Text(
                                  formatDob(info?['dateOfBirth']),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.grey[900],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _LatestCommentsCard(
                              userId: int.tryParse(info?['userID'] ?? ''),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Settings
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _InlineProfileEditorCard(
                          key: ValueKey(info?['userID'] ?? 'guest'),
                        ),
                      ],
                    ),
                  ),
                ),
                // Subscription
                const _SubscriptionSectionDemo(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoTile(
      {required IconData icon, required String title, required String value}) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: Colors.white)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _InlineProfileEditorCard extends StatefulWidget {
  const _InlineProfileEditorCard({super.key});

  @override
  State<_InlineProfileEditorCard> createState() => _InlineProfileEditorCardState();
}

class _InlineProfileEditorCardState extends State<_InlineProfileEditorCard> {
  final _userService = UserService();

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;

  String _gender = 'other';
  DateTime? _dateOfBirth;
  XFile? _avatarFile;
  Uint8List? _avatarBytes;
  String? _avatarCacheKey;

  bool _saving = false;
  String? _error;

  Map<String, String> _lastInfo = const <String, String>{};
  late final VoidCallback _infoListener;

  void _syncFromInfo(Map<String, String> info, {required Map<String, String> oldInfo}) {
    // Avoid clobbering unsaved edits.
    if (_usernameCtrl.text == (oldInfo['userName'] ?? '')) {
      _usernameCtrl.text = info['userName'] ?? '';
    }
    if (_firstNameCtrl.text == (oldInfo['firstName'] ?? '')) {
      _firstNameCtrl.text = info['firstName'] ?? '';
    }
    if (_lastNameCtrl.text == (oldInfo['lastName'] ?? '')) {
      _lastNameCtrl.text = info['lastName'] ?? '';
    }

    final oldGender = (oldInfo['gender'] ?? 'other').toString().toLowerCase();
    if (_gender == oldGender) {
      _gender = (info['gender'] ?? 'other').toString().toLowerCase();
      if (!['male', 'female', 'other'].contains(_gender)) _gender = 'other';
    }

    final oldDob = DateTime.tryParse(oldInfo['dateOfBirth'] ?? '');
    if (_dateOfBirth?.toIso8601String() == oldDob?.toIso8601String()) {
      _dateOfBirth = DateTime.tryParse(info['dateOfBirth'] ?? '');
    }
  }

  @override
  void initState() {
    super.initState();
    final info = currentUserInfo.value ?? const <String, String>{};
    _lastInfo = Map<String, String>.from(info);
    _usernameCtrl = TextEditingController(text: info['userName'] ?? '');
    _firstNameCtrl = TextEditingController(text: info['firstName'] ?? '');
    _lastNameCtrl = TextEditingController(text: info['lastName'] ?? '');

    _gender = (info['gender'] ?? 'other').toString().toLowerCase();
    if (!['male', 'female', 'other'].contains(_gender)) _gender = 'other';
    _dateOfBirth = DateTime.tryParse(info['dateOfBirth'] ?? '');

    // Keep form in sync when currentUserInfo is refreshed from /user/me.
    _infoListener = () {
      if (!mounted) return;
      final infoNow = currentUserInfo.value ?? const <String, String>{};
      final oldInfo = _lastInfo;

      final didUserChange = (oldInfo['userID'] ?? '') != (infoNow['userID'] ?? '');
      final didRelevantChange =
          didUserChange ||
          oldInfo['userName'] != infoNow['userName'] ||
          oldInfo['firstName'] != infoNow['firstName'] ||
          oldInfo['lastName'] != infoNow['lastName'] ||
          oldInfo['gender'] != infoNow['gender'] ||
          oldInfo['dateOfBirth'] != infoNow['dateOfBirth'] ||
          oldInfo['avatar'] != infoNow['avatar'];

      if (!didRelevantChange) return;

      // Update snapshot early to avoid loops.
      _lastInfo = Map<String, String>.from(infoNow);

      if (_saving) {
        setState(() {});
        return;
      }

      if (didUserChange) {
        _avatarFile = null;
        _avatarBytes = null;
        _error = null;
      }

      if (oldInfo['avatar'] != infoNow['avatar']) {
        avatarCacheBuster.value = DateTime.now().millisecondsSinceEpoch.toString();
      }

      _syncFromInfo(infoNow, oldInfo: oldInfo);
      setState(() {});
    };
    currentUserInfo.addListener(_infoListener);
  }

  @override
  void dispose() {
    currentUserInfo.removeListener(_infoListener);
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _avatarFile = file;
      _avatarBytes = bytes;
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    final info = currentUserInfo.value ?? const <String, String>{};
    final userId = int.tryParse(info['userID'] ?? '');
    if (userId == null || userId <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    final newUsername = _usernameCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();

    if (newUsername.isEmpty) {
      setState(() => _error = 'Username is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final oldUsername = (info['userName'] ?? '').toString();
      if (oldUsername.isNotEmpty && newUsername != oldUsername) {
        await _userService.updateUsername(userId: userId, newUsername: newUsername);
      }

      final oldDob = DateTime.tryParse(info['dateOfBirth'] ?? '');
      final shouldUpdateProfile =
          _avatarFile != null ||
          firstName != (info['firstName'] ?? '') ||
          lastName != (info['lastName'] ?? '') ||
          _gender != (info['gender'] ?? 'other').toString().toLowerCase() ||
          (_dateOfBirth?.toIso8601String() != oldDob?.toIso8601String());

      if (shouldUpdateProfile) {
        await _userService.updateProfileMultipart(
          userId: userId,
          newUserName: newUsername,
          firstName: firstName,
          lastName: lastName,
          gender: _gender,
          dateOfBirth: _dateOfBirth,
          avatar: _avatarFile,
        );

        if (_avatarFile != null) {
          _avatarCacheKey = DateTime.now().millisecondsSinceEpoch.toString();
          avatarCacheBuster.value = _avatarCacheKey!;
        }
      }

      // Refresh from /user/me to keep UI consistent with backend
      try {
        final me = await _userService.getMe();
        final profile = (me['profile'] is Map)
            ? Map<String, dynamic>.from(me['profile'] as Map)
            : <String, dynamic>{};
        final meUserName = (me['userName'] ?? '').toString();
        final meEmail = (me['email'] ?? '').toString();
        final meId = (me['userID'] ?? me['userId'] ?? '').toString();

        currentUserInfo.value = {
          'userName': meUserName.isNotEmpty ? meUserName : newUsername,
          'email': meEmail.isNotEmpty ? meEmail : (info['email'] ?? '').toString(),
          if (meId.isNotEmpty) 'userID': meId,
          'firstName': (me['firstName'] ?? profile['firstName'] ?? firstName).toString(),
          'lastName': (me['lastName'] ?? profile['lastName'] ?? lastName).toString(),
          if (((me['avatar'] ?? profile['avatar'])?.toString() ?? '').isNotEmpty)
            'avatar': (me['avatar'] ?? profile['avatar']).toString(),
          if (((me['gender'] ?? profile['gender'])?.toString() ?? '').isNotEmpty)
            'gender': (me['gender'] ?? profile['gender']).toString(),
          if (((me['dateOfBirth'] ?? profile['dateOfBirth'])?.toString() ?? '').isNotEmpty)
            'dateOfBirth': (me['dateOfBirth'] ?? profile['dateOfBirth']).toString(),
        };
        isLoggedIn.value = true;
      } catch (_) {
        currentUserInfo.value = {
          ...info.map((k, v) => MapEntry(k, v?.toString() ?? '')),
          'userName': newUsername,
          'firstName': firstName,
          'lastName': lastName,
          'gender': _gender,
          if (_dateOfBirth != null) 'dateOfBirth': _dateOfBirth!.toIso8601String(),
        };
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = currentUserInfo.value ?? const <String, String>{};
    final avatarUrl = cacheBustUrl(
      resolveApiUrl(info['avatar']),
      cacheKey: _avatarCacheKey,
    );
    final hasNetworkAvatar = _avatarBytes == null && avatarUrl.isNotEmpty;
    final dobLabel = _dateOfBirth == null
        ? 'Not set'
        : DateFormat('yyyy-MM-dd').format(_dateOfBirth!);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.red,
                  backgroundImage: _avatarBytes != null
                      ? MemoryImage(_avatarBytes!)
                      : (hasNetworkAvatar ? NetworkImage(avatarUrl) : null)
                          as ImageProvider<Object>?,
                  child: (_avatarBytes == null && !hasNetworkAvatar)
                      ? Text(
                          (info['userName'] ?? 'U').isNotEmpty
                              ? (info['userName'] ?? 'U')![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickAvatar,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Change Photo'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
              enabled: !_saving,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'First name'),
                    enabled: !_saving,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    enabled: !_saving,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: _saving ? null : (v) => setState(() => _gender = v ?? 'other'),
              decoration: const InputDecoration(labelText: 'Gender'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Date of birth: $dobLabel',
                      style: const TextStyle(color: Colors.white70)),
                ),
                OutlinedButton(
                  onPressed: _saving ? null : _pickDob,
                  child: const Text('Pick'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LatestCommentsCard extends StatefulWidget {
  final int? userId;

  const _LatestCommentsCard({required this.userId});

  @override
  State<_LatestCommentsCard> createState() => _LatestCommentsCardState();
}

class _LatestCommentsCardState extends State<_LatestCommentsCard> {
  bool _loading = false;
  String? _error;
  List<CommentDemo> _comments = const [];
  final Map<int, String> _movieTitles = <int, String>{};

  @override
  void initState() {
    super.initState();

    for (final m in appMovies) {
      _movieTitles[m.id] = m.title;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void didUpdateWidget(covariant _LatestCommentsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _load();
    }
  }

  Future<String?> _fetchMovieTitle(int movieId) async {
    try {
      final uri =
          Uri.parse('${AppConstants.baseApiUrl}/api/Movie/GetMovieById/$movieId');
      final res = await _httpClient.get(uri, headers: _authHeaders());
      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body);
      final data = _unwrapResponseData(decoded);
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data as Map);

      final title = (map['title'] as String?) ??
          (map['originalTitle'] as String?) ??
          (map['name'] as String?);
      if (title == null || title.trim().isEmpty) return null;
      return title.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final userId = widget.userId;
    if (userId == null || userId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Please sign in to view your comments';
        _comments = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
          '${AppConstants.baseApiUrl}/api/Comment/GetCommentsByUserID/$userId?userID=$userId');
      final res = await _httpClient.get(uri, headers: _authHeaders());

      if (res.statusCode == 401) throw Exception('HTTP_401');
      if (res.statusCode == 403) throw Exception('HTTP_403');
      if (res.statusCode != 200) {
        throw Exception(
            'Failed to fetch comments (HTTP ${res.statusCode}): ${_previewBody(res.body)}');
      }

      final decoded = jsonDecode(res.body);
      final data = _unwrapResponseData(decoded);
      if (data is! List) {
        throw Exception('Comments returned unexpected shape');
      }

      final list = <CommentDemo>[];
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          list.add(CommentDemo.fromJson(item));
        } else if (item is Map) {
          list.add(CommentDemo.fromJson(Map<String, dynamic>.from(item as Map)));
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Hydrate movie titles for the first 5 comments.
      final top = list.take(5).toList();
      final uniqueMovieIds = top.map((c) => c.movieID).toSet();
      for (final movieId in uniqueMovieIds) {
        if (movieId <= 0) continue;
        if (_movieTitles.containsKey(movieId)) continue;
        final title = await _fetchMovieTitle(movieId);
        if (title != null) {
          _movieTitles[movieId] = title;
        }
      }

      if (!mounted) return;
      setState(() {
        _comments = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final prompt = authzPromptFromError(e);
      setState(() {
        _loading = false;
        if (prompt == AuthzPromptType.signIn) {
          _error = 'Please sign in to view your comments';
        } else if (prompt == AuthzPromptType.buyPlan) {
          _error = 'Please buy a plan to view your comments';
        } else {
          _error = e.toString();
        }
        _comments = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final totalCount = _comments.length;
    final shown = _comments.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Latest Comments',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.white70))
        else if (shown.isEmpty)
          const Text('No comments yet', style: TextStyle(color: Colors.white70))
        else
          ...shown.map((c) {
            final movieTitle = _movieTitles[c.movieID] ?? 'Movie #${c.movieID}';
            final dateStr = df.format(c.createdAt);
            return InkWell(
              onTap: c.movieID > 0 ? () => context.go('/movie/${c.movieID}') : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  movieTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(dateStr,
                                  style:
                                      const TextStyle(color: Colors.white54)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.content.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            );
          }),
        if (!_loading && _error == null && totalCount > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Showing 5 of $totalCount comments',
                style: const TextStyle(color: Colors.white54)),
          ),
      ],
    );
  }
}

class _SubscriptionSectionDemo extends StatefulWidget {
  const _SubscriptionSectionDemo();

  @override
  State<_SubscriptionSectionDemo> createState() =>
      _SubscriptionSectionDemoState();
}

class _SubscriptionSectionDemoState extends State<_SubscriptionSectionDemo> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _currentPlan; // { name, status, expiry }
  List<Map<String, dynamic>> _plans = []; // [{ id, name, code, isActive }]
  Map<String, String> _planPriceLabel = {}; // planId -> "amount currency"
  final Map<String, int> _planFirstPriceId =
      {}; // planId -> priceID (first/primary)
  final Map<String, Map<String, dynamic>> _planPriceInfo =
      {}; // planId -> { priceID, amount, currency, intervalUnit, intervalCount }

  String? _selectedPlanId;
  bool _showBillingHistory = false;
  List<Map<String, dynamic>> _billingHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = StorageService.getUserToken();
      final authHeaders = (token != null && token.isNotEmpty)
          ? <String, String>{'Authorization': 'Bearer $token'}
          : const <String, String>{};

      // Load prices
      final pricesRes = await http.get(
        Uri.parse('${AppConstants.baseApiUrl}/api/price/all'),
        headers: authHeaders,
      );
      List<dynamic> prices = [];
      if (pricesRes.statusCode >= 200 && pricesRes.statusCode < 300) {
        final body = json.decode(pricesRes.body);
        prices = body is Map<String, dynamic>
            ? (body['data'] ?? body['Data'] ?? [])
            : (body as List? ?? []);
      }

      // Load plans
      final plansRes = await http.get(
        Uri.parse('${AppConstants.baseApiUrl}/api/plans/all'),
        headers: authHeaders,
      );
      List<dynamic> plansRaw = [];
      if (plansRes.statusCode >= 200 && plansRes.statusCode < 300) {
        final body = json.decode(plansRes.body);
        plansRaw = body is Map<String, dynamic>
            ? (body['data'] ?? body['Data'] ?? [])
            : (body as List? ?? []);
      }
      final activePlans =
          plansRaw.where((p) => (p['isActive'] ?? true) != false).toList();
      _plans = activePlans
          .map<Map<String, dynamic>>((p) => {
                'id': p['planID'] ?? p['planId'] ?? p['id'],
                'name': p['name'] ?? p['code'] ?? 'Plan',
                'code': p['code'],
                'isActive': p['isActive'] ?? true,
                'description': p['description'],
              })
          .toList();

      // Map first matching price per plan
      final Map<String, String> priceLabel = {};
      for (final p in _plans) {
        final pid = (p['id'] ?? '').toString();
        final matched = prices.firstWhere(
          (pr) =>
              (pr['planID']?.toString() ?? pr['planId']?.toString() ?? '') ==
              pid,
          orElse: () => null,
        );
        if (matched != null) {
          final amount = matched['amount'];
          final currency = matched['currency'] ?? '';
          final priceId = matched['priceID'] ?? matched['priceId'];
          if (amount != null) {
            final amountNum = double.tryParse(amount.toString());
            priceLabel[pid] = (amountNum != null && amountNum == 0)
                ? 'Free'
                : '${amount ?? 'N/A'} ${currency}'.trim();
          }
          if (priceId != null) {
            final pidInt = int.tryParse(priceId.toString());
            if (pidInt != null) _planFirstPriceId[pid] = pidInt;
          }
          _planPriceInfo[pid] = {
            'priceID': priceId,
            'amount': amount,
            'currency': currency,
            'intervalUnit': matched['intervalUnit'] ?? 'month',
            'intervalCount': matched['intervalCount'] ?? 1,
          };
        }
      }
      _planPriceLabel = priceLabel;

      // Current subscription by user
      final info = currentUserInfo.value;
      final userIdStr = info?['userID'] ?? info?['userId'];
      final userId = int.tryParse(userIdStr ?? '');
      if (userId != null && userId > 0) {
        final subsRes = await http.get(
          Uri.parse(
              '${AppConstants.baseApiUrl}/api/payment/subscription/user/$userId'),
          headers: authHeaders,
        );
        if (subsRes.statusCode >= 200 && subsRes.statusCode < 300) {
          final body = json.decode(subsRes.body);
          final arr = body is Map<String, dynamic>
              ? (body['data'] ?? body['Data'] ?? [])
              : (body as List? ?? []);
          if (arr.isNotEmpty) {
            // pick latest by subscriptionID
            arr.sort((a, b) => ((b['subscriptionID'] ??
                    b['subscriptionId'] ??
                    0) as num)
                .compareTo(
                    (a['subscriptionID'] ?? a['subscriptionId'] ?? 0) as num));
            final latest = arr.first;
            // resolve plan name
            var planId = latest['planID'] ?? latest['planId'];
            if (planId == null && latest['priceID'] != null) {
              try {
                final priceRes = await http.get(
                  Uri.parse(
                      '${AppConstants.baseApiUrl}/api/price/${latest['priceID']}'),
                  headers: authHeaders,
                );
                if (priceRes.statusCode >= 200 && priceRes.statusCode < 300) {
                  final pb = json.decode(priceRes.body);
                  final pdata = pb is Map<String, dynamic>
                      ? (pb['data'] ?? pb['Data'])
                      : null;
                  planId = pdata != null
                      ? (pdata['planID'] ?? pdata['planId'])
                      : planId;
                }
              } catch (_) {}
            }
            String planName = 'Current Plan';
            if (planId != null) {
              try {
                final planRes = await http.get(
                  Uri.parse('${AppConstants.baseApiUrl}/api/plans/${planId}'),
                  headers: authHeaders,
                );
                if (planRes.statusCode >= 200 && planRes.statusCode < 300) {
                  final pb = json.decode(planRes.body);
                  final pdata = pb is Map<String, dynamic>
                      ? (pb['data'] ?? pb['Data'])
                      : null;
                  if (pdata != null) {
                    planName = pdata['name'] ?? pdata['code'] ?? planName;
                  }
                }
              } catch (_) {}
            }
            String? expiry;
            if (latest['currentPeriodEnd'] != null) {
              try {
                final d =
                    DateTime.tryParse(latest['currentPeriodEnd'].toString());
                if (d != null)
                  expiry =
                      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              } catch (_) {}
            }
            final status = (latest['status'] ?? 'active').toString();
            _currentPlan = {
              'name': planName,
              'status': status,
              'expiry': expiry,
              'planId': planId?.toString(),
            };

            _billingHistory = arr.map<Map<String, dynamic>>((it) {
              final planNameHist = (it['planName'] ?? planName).toString();
              final statusHist = (it['status'] ?? '').toString();
              String date = '';
              final rawDate = it['currentPeriodEnd'] ?? it['createdAt'] ?? it['created_at'];
              if (rawDate != null) {
                final dt = DateTime.tryParse(rawDate.toString());
                if (dt != null) {
                  date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                } else {
                  date = rawDate.toString();
                }
              }
              return {
                'planName': planNameHist,
                'status': statusHist,
                'date': date,
              };
            }).toList();
          }
        }
      }

      if (_selectedPlanId == null) {
        final current = _currentPlan?['planId']?.toString();
        final hasCurrent = current != null && _plans.any((p) => p['id']?.toString() == current);
        _selectedPlanId = hasCurrent ? current : (_plans.isNotEmpty ? _plans.first['id']?.toString() : null);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  String _formatAmount(dynamic amount, String currency) {
    final numVal = (amount is num)
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? 0.0;
    final nf = NumberFormat.decimalPattern();
    final amt = nf.format(numVal);
    return '$amt ${currency.toUpperCase()}';
  }

  Future<void> _startCheckout(int priceId) async {
    try {
      final token = StorageService.getUserToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.signIn,
          onPrimary: () => context.go('/signin'),
        );
        return;
      }
      final uri =
          Uri.parse('${AppConstants.baseApiUrl}/api/payment/vnpay/checkout');
      final res = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'PriceId': priceId,
          'AutoRenew': false,
        }),
      );
      if (res.statusCode == 401) throw Exception('HTTP_401');
      if (res.statusCode == 403) throw Exception('HTTP_403');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Checkout failed (${res.statusCode})');
      }
      final body = json.decode(res.body);
      final data = body is Map<String, dynamic> ? (body['data'] ?? body['Data']) : null;
      final payUrl = (data is Map<String, dynamic>)
          ? (data['paymentUrl'] ?? data['payUrl'] ?? data['url'])
          : (body is Map<String, dynamic>
              ? (body['paymentUrl'] ?? body['payUrl'] ?? body['PayUrl'] ?? body['url'])
              : null);
      if (payUrl is String && payUrl.isNotEmpty) {
        await launchUrl(Uri.parse(payUrl),
            mode: LaunchMode.externalApplication);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment page opened in a new tab')));
      } else {
        throw Exception('Missing payment URL');
      }
    } catch (e) {
      if (!mounted) return;
      final prompt = authzPromptFromError(e);
      if (prompt == AuthzPromptType.signIn) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.signIn,
          onPrimary: () => context.go('/signin'),
        );
        return;
      }
      if (prompt == AuthzPromptType.buyPlan) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.buyPlan,
          onPrimary: () => context.go('/profile'),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout error: ${e.toString()}')));
    }
  }

  Widget _buildCurrentPlanCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _currentPlan == null) {
      return const _SubscriptionRedOutlinedCard(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_currentPlan == null) {
      return const _SubscriptionRedOutlinedCard(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No active subscription', textAlign: TextAlign.center),
        ),
      );
    }

    final name = (_currentPlan?['name'] ?? 'Plan').toString();
    final status = (_currentPlan?['status'] ?? '').toString();
    final expiry = (_currentPlan?['expiry'] ?? '').toString();

    return _SubscriptionRedOutlinedCard(
      fillColor: cs.primary.withOpacity(0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              status.isEmpty ? '—' : status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.70)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              expiry.isEmpty ? 'Expires: —' : 'Expires: $expiry',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _plans.firstWhere(
      (p) => p['id']?.toString() == _selectedPlanId,
      orElse: () => const <String, dynamic>{},
    );
    final selectedName = (selected['name'] ?? '').toString();
    final selectedPriceId = _selectedPlanId == null ? null : _planFirstPriceId[_selectedPlanId!];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              _SubscriptionRedOutlinedCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Failed to load subscription info: $_error'),
                ),
              ),
            const _SubscriptionSectionHeader(title: 'Current Plan'),
            const SizedBox(height: 10),
            _buildCurrentPlanCard(context),
            const SizedBox(height: 18),
            const _SubscriptionSectionHeader(title: 'Choose Plan'),
            const SizedBox(height: 10),
            if (_loading && _plans.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_plans.isEmpty)
              const _SubscriptionRedOutlinedCard(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No active plans available.'),
                ),
              )
            else
              ..._plans.map((p) {
                final pid = p['id']?.toString() ?? '';
                final isSelected = pid.isNotEmpty && pid == _selectedPlanId;

                final priceInfo = _planPriceInfo[pid];
                final amountLabel = priceInfo == null
                    ? (_planPriceLabel[pid] ?? 'N/A')
                    : _formatAmount(priceInfo['amount'], (priceInfo['currency'] ?? 'VND').toString());
                final intervalUnit = (priceInfo?['intervalUnit'] ?? 'month').toString();
                final intervalCount = int.tryParse((priceInfo?['intervalCount'] ?? 1).toString()) ?? 1;
                final perLabel = intervalUnit.isEmpty ? '' : '/ ${intervalCount > 1 ? '$intervalCount ' : ''}$intervalUnit';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubscriptionPlanCard(
                    title: (p['name'] ?? 'Plan').toString(),
                    price: amountLabel,
                    per: perLabel,
                    description: (p['description'] ?? '').toString(),
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedPlanId = pid;
                      });
                    },
                  ),
                );
              }),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (selectedPriceId == null) ? null : () => _startCheckout(selectedPriceId),
                child: Text(
                  selectedName.isEmpty ? 'Continue' : 'Continue with plan *$selectedName',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SubscriptionBillingHistoryCard(
              isExpanded: _showBillingHistory,
              onToggle: () {
                setState(() {
                  _showBillingHistory = !_showBillingHistory;
                });
              },
              items: _billingHistory,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cancel subscription: coming soon')));
                },
                child: const Text('Cancel Subscription'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionSectionHeader extends StatelessWidget {
  final String title;
  const _SubscriptionSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _SubscriptionRedOutlinedCard extends StatelessWidget {
  final Widget child;
  final Color? fillColor;
  const _SubscriptionRedOutlinedCard({required this.child, this.fillColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: fillColor ?? cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary, width: 1.2),
      ),
      child: child,
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String per;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubscriptionPlanCard({
    required this.title,
    required this.price,
    required this.per,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = isSelected ? cs.primary : cs.outlineVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$price ${per.trim()}'.trim(),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurface.withOpacity(0.70)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionBillingHistoryCard extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Map<String, dynamic>> items;

  const _SubscriptionBillingHistoryCard({
    required this.isExpanded,
    required this.onToggle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SubscriptionRedOutlinedCard(
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Show Billing History (i)',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  const Divider(height: 18),
                  if (items.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No billing history',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    ...items.map((it) {
                      final plan = (it['planName'] ?? '').toString();
                      final status = (it['status'] ?? '').toString();
                      final date = (it['date'] ?? '').toString();

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: cs.primary.withOpacity(0.9), width: 1.0),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.isEmpty ? 'SUBSCRIPTION' : plan.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: cs.primary,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              if (status.isNotEmpty)
                                Text('Status: $status',
                                    style: Theme.of(context).textTheme.bodySmall),
                              if (date.isNotEmpty)
                                Text(date,
                                    style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _OverviewTile(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: Colors.white)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Search Screen
class SearchScreen extends StatefulWidget {
  final String query;

  const SearchScreen({super.key, required this.query});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Movie> searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.query;
    _performSearch(widget.query);
  }

  void _performSearch(String query) {
    setState(() {
      searchResults = appMovies.where((movie) {
        return movie.title.toLowerCase().contains(query.toLowerCase()) ||
            movie.description.toLowerCase().contains(query.toLowerCase()) ||
            movie.genres.any(
                (genre) => genre.toLowerCase().contains(query.toLowerCase()));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search movies and TV shows...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _performSearch,
            ),
            const SizedBox(height: 20),

            // Search Results
            Expanded(
              child: searchResults.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, color: Colors.grey, size: 80),
                          SizedBox(height: 16),
                          Text(
                            'No results found',
                            style: TextStyle(color: Colors.grey, fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final movie = searchResults[index];
                        return GestureDetector(
                          onTap: () => context.go('/movie/${movie.id}'),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(movie.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8)
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      movie.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      movie.year,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple Sign In screen for demo
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _error;
  final AuthService _authService = AuthService();

  void _attemptLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Email and password required.');
      return;
    }
    setState(() => _error = null);
    try {
      final result = await _authService.signIn(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (result['success'] == true) {
        final res = result['data'];
        final dynamic inner = res is Map<String, dynamic>
            ? (res['data'] ?? res['Data'] ?? res)
            : res;
        if (inner is Map<String, dynamic>) {
          final userName = inner['userName']?.toString() ?? '';
          final email = inner['email']?.toString() ?? '';
          final userId = inner['userID']?.toString();
          final token = inner['token']?.toString();
          currentUserInfo.value = {
            'userName': userName,
            'email': email,
            if (userId != null) 'userID': userId,
          };
          if (token != null && token.isNotEmpty) {
            StorageService.saveUserToken(token);
          }
        }

        // Hydrate full profile from /user/me (includes avatar) so the UI
        // doesn't stick to defaults after login.
        try {
          final me = await UserService().getMe();
          final Map<String, dynamic>? profile = (me['profile'] is Map)
              ? Map<String, dynamic>.from(me['profile'] as Map)
              : null;

          final userName =
              (me['userName'] ?? me['UserName'] ?? me['name'] ?? '').toString();
          final email = (me['email'] ?? me['Email'] ?? '').toString();
          final userId = (me['userID'] ?? me['UserID'] ?? me['id'])?.toString();
          final firstName = (me['firstName'] ?? profile?['firstName'] ?? '')
              .toString();
          final lastName =
              (me['lastName'] ?? profile?['lastName'] ?? '').toString();
          final avatar =
              (me['avatar'] ?? profile?['avatar'] ?? '').toString();
          final gender =
              (me['gender'] ?? profile?['gender'] ?? '').toString();
          final dateOfBirth =
              (me['dateOfBirth'] ?? profile?['dateOfBirth'] ?? '').toString();

          currentUserInfo.value = {
            'userName': userName,
            'email': email,
            if (userId != null) 'userID': userId,
            if (firstName.isNotEmpty) 'firstName': firstName,
            if (lastName.isNotEmpty) 'lastName': lastName,
            if (avatar.isNotEmpty) 'avatar': avatar,
            if (gender.isNotEmpty) 'gender': gender,
            if (dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
          };
          if (avatar.isNotEmpty) {
            avatarCacheBuster.value =
                DateTime.now().millisecondsSinceEpoch.toString();
          }
        } catch (_) {
          // ignore: fall back to login response
        }

        isLoggedIn.value = true;
        unawaited(refreshSavedMoviesForCurrentUser());
        if (!mounted) return;
        context.go('/');
      } else {
        setState(() => _error = result['message'] ?? 'Sign in failed.');
      }
    } catch (e) {
      setState(() => _error = 'Network error: ${e.toString()}');
    }
  }

  Future<void> _startGoogleLogin() async {
    // Ensure backend redirects back to your home
    final url = _authService.getGoogleLoginRedirectUrl(
        returnUrl: 'http://localhost:3000/home');
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) context.push(Uri.parse(url).path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sign in'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'FlixGo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Discover Amazing Movies & TV Shows',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
                onSubmitted: (_) => _attemptLogin(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _attemptLogin,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _startGoogleLogin,
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
              TextButton(
                onPressed: () => context.go('/signup'),
                child: const Text('Need an account? Sign up'),
              ),
              TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _gender; // start empty so label floats like other fields
  String? _error;

  Future<void> _startGoogleSignUp() async {
    // For web, Google sign-up is the same as Google sign-in.
    // Backend creates/links the account during OAuth.
    final returnUrl = Uri.base.origin;
    final url = _authService.getGoogleLoginRedirectUrl(returnUrl: returnUrl);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) context.push(url);
    }
  }

  void _attemptSignup() async {
    if (_usernameController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        !_emailController.text.contains('@') ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() => _error = null);
    try {
      final result = await _authService.signUp(
        _usernameController.text.trim(),
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        gender: _gender ?? 'other',
      );
      if (result['success'] == true) {
        final res = result['data'];
        final dynamic inner = res is Map<String, dynamic>
            ? (res['data'] ?? res['Data'] ?? res)
            : res;
        final userId =
            (inner is Map<String, dynamic>) ? inner['userID'] as int? : null;
        if (!mounted) return;
        if (userId != null) {
          context.go('/verify-email?userID=$userId');
        } else {
          setState(() => _error = 'Missing userID in response.');
        }
      } else {
        setState(() => _error = result['message'] ?? 'Sign up failed.');
      }
    } catch (e) {
      setState(() => _error = 'Network error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sign up'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'FlixGo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join and Explore New Titles',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 16),
              // Gender (Dropdown)
              DropdownButtonFormField<String>(
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) => setState(() => _gender = val),
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              TextField(
                controller: _firstNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _attemptSignup,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Create account'),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _startGoogleSignUp,
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
              TextButton(
                onPressed: () => context.go('/signin'),
                child: const Text('Already have an account? Sign in'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class VerifyEmailScreen extends StatefulWidget {
  final int userId;
  const VerifyEmailScreen({super.key, required this.userId});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  String? _error;
  bool _isLoading = false;

  void _verify() async {
    final code = _codeControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _error = 'Enter 6 digits.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await _authService.verifyEmail(widget.userId, code);
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        if (!mounted) return;
        context.go('/signin');
      } else {
        setState(
            () => _error = result['message'] ?? 'Invalid verification code.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Network error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the 6-digit verification code sent to your email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _codeControllers[i],
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: const InputDecoration(
                        counterText: '',
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.red)),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify Email'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Forgot Password Flow
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();

  String? _error;
  bool _isLoading = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  _CleanForgotStage _stage = _CleanForgotStage.email;
  String? _ticket;

  bool _isOk(Map<String, dynamic> res) {
    final s = res['success'];
    if (s == true) return true;
    final ec = res['errorCode'];
    if (ec is int && ec >= 200 && ec < 300) return true;
    return false;
  }

  String _messageFrom(Map<String, dynamic> res, String fallback) {
    final msg = res['errorMessage'] ?? res['message'] ?? res['Message'];
    if (msg is String && msg.trim().isNotEmpty) return msg;
    return fallback;
  }

  Future<void> _start() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _authService.startForgotPasswordByEmail(email);
      if (!mounted) return;
      if (_isOk(res)) {
        setState(() {
          _stage = _CleanForgotStage.verify;
          _codeController.text = '';
        });
      } else {
        setState(() =>
            _error = _messageFrom(res, 'Failed to send verification code'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _authService.verifyForgotPasswordByEmail(
        email: _emailController.text.trim(),
        code: code,
      );
      if (!mounted) return;

      if (_isOk(res)) {
        final dynamic data = res['data'] ?? res['Data'] ?? res;
        final ticket = (data is String) ? data : null;
        if (ticket == null || ticket.trim().isEmpty) {
          setState(
              () => _error = 'Missing verification ticket. Please try again.');
          return;
        }
        setState(() {
          _ticket = ticket;
          _stage = _CleanForgotStage.commit;
          _newPasswordController.text = '';
          _confirmPasswordController.text = '';
          _showNewPassword = false;
          _showConfirmPassword = false;
        });
      } else {
        setState(() => _error = _messageFrom(res, 'Invalid verification code'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _commit() async {
    final ticket = _ticket;
    if (ticket == null || ticket.isEmpty) {
      setState(() => _error = 'Missing ticket. Please restart.');
      return;
    }

    final p1 = _newPasswordController.text.trim();
    final p2 = _confirmPasswordController.text.trim();
    if (p1.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters.');
      return;
    }
    if (p1 != p2) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _authService.commitForgotPassword(
        ticket: ticket,
        newPassword: p1,
      );
      if (!mounted) return;

      if (_isOk(res)) {
        setState(() => _stage = _CleanForgotStage.done);
      } else {
        setState(() => _error = _messageFrom(res, 'Failed to reset password'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Reset Your Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              if (_stage == _CleanForgotStage.email) ...[
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red)),
                  ),
                  onSubmitted: (_) => _start(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _start,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send code'),
                ),
              ] else if (_stage == _CleanForgotStage.verify) ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red)),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify code'),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _stage = _CleanForgotStage.email;
                            _codeController.text = '';
                          });
                        },
                  child: const Text('Change email'),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _start,
                  child: const Text('Resend code'),
                ),
              ] else if (_stage == _CleanForgotStage.commit) ...[
                TextField(
                  controller: _newPasswordController,
                  obscureText: !_showNewPassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'New password',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red)),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showNewPassword = !_showNewPassword),
                      icon: Icon(
                        _showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_showConfirmPassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red)),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword),
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _commit(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _commit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset password'),
                ),
              ] else ...[
                const Icon(Icons.check_circle_outline,
                    color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Password reset successfully. Please sign in again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/signin'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: const Text('Return to Sign in'),
                ),
              ],
              TextButton(
                onPressed: () => context.go('/signin'),
                child: const Text('Back to Sign in'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _CleanForgotStage { email, verify, commit, done }

class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Check Your Email'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, color: Colors.red, size: 72),
              const SizedBox(height: 24),
              const Text(
                'We\'ve sent a password reset link to your email if it exists in our system.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/signin'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Return to Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
