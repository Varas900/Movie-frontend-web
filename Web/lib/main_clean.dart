import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flixgo_web/core/utils/app_constants.dart';
import 'package:go_router/go_router.dart';
import 'package:flixgo_web/core/services/auth_service.dart';
import 'package:flixgo_web/core/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Simple global auth flag. In a real app, replace with Provider/Bloc.
final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
// Minimal current user info for demo profile rendering
final ValueNotifier<Map<String, String>?> currentUserInfo =
    ValueNotifier<Map<String, String>?>(null);

void main() {
  runApp(const FlixGoApp());
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
  final List<Actor> actors;

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
    required this.actors,
  });
}

class Actor {
  final String name;
  final String character;
  final String? avatarUrl;

  const Actor({
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
    return CommentDemo(
      commentID: (json['commentID'] as num?)?.toInt() ?? 0,
      movieID: (json['movieID'] as num?)?.toInt() ?? 0,
      userID: (json['userID'] as num?)?.toInt() ?? 0,
      userName: json['userName'] as String?,
      content: json['content'] as String? ?? '',
      parentID: (json['parentID'] as num?)?.toInt(),
      isEdited: json['isEdited'] as bool? ?? false,
      likeCount: (json['likeCount'] as num?)?.toInt(),
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
        return matches.isNotEmpty
            ? MovieDetailsScreen(movie: matches.first)
            : const HomeScreen();
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
          final userName =
              (data['userName'] ?? data['UserName'] ?? data['name'] ?? '')
                  .toString();
          final email = (data['email'] ?? data['Email'] ?? '').toString();
          final userId =
              (data['userID'] ?? data['UserID'] ?? data['id'])?.toString();
          currentUserInfo.value = {
            'userName': userName,
            'email': email,
            if (userId != null) 'userID': userId,
          };
          isLoggedIn.value = true;
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

  void _filterMovies(String query) {
    setState(() {
      filteredMovies = appMovies.where((movie) {
        final matchesQuery =
            movie.title.toLowerCase().contains(query.toLowerCase()) ||
                movie.description.toLowerCase().contains(query.toLowerCase());
        final matchesGenre =
            selectedGenre == 'All' || movie.genres.contains(selectedGenre);
        return matchesQuery && matchesGenre;
      }).toList();
    });
  }

  void _selectGenre(String genre) {
    setState(() {
      selectedGenre = genre;
    });
    _filterMovies(_searchController.text);
  }

  Future<void> _fetchAllMovies() async {
    try {
      final url = Uri.parse(
          '${AppConstants.baseApiUrl}/api/Movie/GetAllMoviesMainScreen/mainScreen');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final List<dynamic> items = body['data'] as List<dynamic>;
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
            actors: const [],
          );
        }).toList();

        // Fetch tags and movies-per-tag, then assign genres to each movie
        final allTags = await _fetchAllTags();
        final tagIdToName = <int, String>{
          for (final t in allTags)
            ((t['tagID'] as num).toInt()): (t['tagName']?.toString() ?? '')
        };
        final Map<int, Set<int>> tagToMovieIds = {};
        await Future.wait(tagIdToName.keys.map((tagId) async {
          final ids = await _fetchMovieIdsForTag(tagId);
          tagToMovieIds[tagId] = ids;
        }));

        final updated = fetched.map((mv) {
          final gNames = <String>[];
          tagToMovieIds.forEach((tagId, ids) {
            if (ids.contains(mv.id)) {
              final name = tagIdToName[tagId];
              if (name != null && name.isNotEmpty) gNames.add(name);
            }
          });
          gNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          return Movie(
            id: mv.id,
            title: mv.title,
            description: mv.description,
            imageUrl: mv.imageUrl,
            year: mv.year,
            rating: mv.rating,
            popularity: mv.popularity,
            genres: gNames,
            duration: mv.duration,
            actors: mv.actors,
          );
        }).toList();

        final names = tagIdToName.values
            .where((n) => n.trim().isNotEmpty)
            .map((n) => n.trim())
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        setState(() {
          availableGenres = ['All', ...names];
          appMovies = updated;
          filteredMovies = updated;
          _isLoading = false;
        });
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

  // Fetch all tags (genres) from API
  Future<List<Map<String, dynamic>>> _fetchAllTags() async {
    final uri =
        Uri.parse('${AppConstants.baseApiUrl}/movie/Tag/GetAllTags/getALlTags');
    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(res.body);
    final data = body is Map<String, dynamic>
        ? (body['data'] ?? body['Data'] ?? body)
        : body;
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
      final res = await http.get(uri);
      if (res.statusCode != 200) return <int>{};
      final body = jsonDecode(res.body);
      final data = body is Map<String, dynamic>
          ? (body['data'] ?? body['Data'] ?? body)
          : body;
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
                            return GestureDetector(
                              onTap: () => context.go('/profile'),
                              child: const CircleAvatar(
                                backgroundColor: Colors.red,
                                radius: 18,
                                child: Icon(Icons.person,
                                    color: Colors.white, size: 18),
                              ),
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
class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
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
                          _MetaChip(label: '${movie.duration} min'),
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
                                      showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        builder: (_) => InlinePlayerDialogDemo(
                                            movieId: movie.id),
                                      );
                                    }),
                                    const SizedBox(height: 12),
                                    _AddToListButton(onTap: () {}),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _PlayButton(onTap: () {
                                        showDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          builder: (_) =>
                                              InlinePlayerDialogDemo(
                                                  movieId: movie.id),
                                        );
                                      }),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 220,
                                      child: _AddToListButton(onTap: () {}),
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
                            return SizedBox(
                              width: 110,
                              child: Column(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                      color: Colors.grey[850],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      actor.name[0],
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
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0x22FFFFFF)),
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
  const _AddToListButton({required this.onTap});

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
      icon: const Icon(Icons.add),
      label: const Text('My List', style: TextStyle(fontSize: 15)),
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

  Future<void> _loadSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _sources = [];
    });

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

      // Fallback: watchNow endpoint
      // Fallback: watchNow endpoint
      final watchNow = await _fetchWatchNow(widget.movie.id);
      if (watchNow.isNotEmpty) {
        setState(() {
          _sources = watchNow;
          _isLoading = false;
        });
        await _setupPlayerForSource(watchNow[0]);
        return;
      }

      setState(() {
        _error = 'No playable sources available.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load sources: $e';
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

  Future<List<_PlayableSourceDemo>> _fetchWatchNow(int movieId) async {
    final url = Uri.parse(
        '${AppConstants.baseApiUrl}/api/Movie/GetWatchNowMovieByID/watchNow/$movieId');
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body);
    final List<_PlayableSourceDemo> out = [];
    if (body is Map) {
      final singleUrl = body['sourceUrl'] ?? body['url'] ?? body['movieUrl'];
      if (singleUrl is String && singleUrl.isNotEmpty) {
        final id = body['sourceID'] ?? body['id'];
        final quality = body['quality']?.toString();
        final isVip = body['isVip'] == true;
        final src = _PlayableSourceDemo(
          id: id is int ? id : int.tryParse('$id'),
          url: singleUrl,
          quality: quality,
          isVip: isVip,
        );
        final withSubs = await _attachSubtitles([src]);
        out.addAll(withSubs);
      }
      final sources = body['sources'] ?? body['movieSources'] ?? body['data'];
      if (sources is List) {
        for (final s in sources) {
          if (s is Map) {
            final sourceUrl = s['sourceUrl'] ?? s['url'];
            if (sourceUrl is String && sourceUrl.isNotEmpty) {
              final id = s['sourceID'] ?? s['id'];
              final quality = s['quality']?.toString();
              final isVip = s['isVip'] == true;
              out.add(_PlayableSourceDemo(
                id: id is int ? id : int.tryParse('$id'),
                url: sourceUrl,
                quality: quality,
                isVip: isVip,
              ));
            }
          }
        }
        final withSubs = await _attachSubtitles(out);
        return withSubs;
      }
    }
    return out;
  }

  Future<List<_PlayableSourceDemo>> _fetchMovieSources(int movieId) async {
    final url = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/MovieSource/GetMovieSourcesByMovieIdPublic/getByMovieId/$movieId');
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
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
  final int movieId;
  const InlinePlayerDialogDemo({super.key, required this.movieId});

  @override
  State<InlinePlayerDialogDemo> createState() => _InlinePlayerDialogDemoState();
}

class _InlinePlayerDialogDemoState extends State<InlinePlayerDialogDemo>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final src = await _fetchPrimarySource(widget.movieId) ??
          await _fetchWatchNowSource(widget.movieId);
      if (src == null) {
        setState(() {
          _error = 'No playable source';
          _loading = false;
        });
        return;
      }
      _currentSource = src;
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
        _loading = false;
      });
      _scheduleHideUI();
    } catch (e) {
      setState(() {
        _error = 'Playback failed: $e';
        _loading = false;
      });
    }
  }

  Future<_DemoSource?> _fetchPrimarySource(int id) async {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/MovieSource/GetMovieSourcesByMovieIdPublic/getByMovieId/$id');
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    final data = body is Map ? (body['data'] ?? body['Data'] ?? body) : body;
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map) {
        final url = first['sourceUrl'] ?? first['url'];
        final id0 = first['movieSourceID'] ?? first['sourceID'] ?? first['id'];
        final sid = id0 is int ? id0 : int.tryParse('$id0');
        if (sid != null && url is String && url.isNotEmpty) {
          final subs = await _fetchSubtitlesBySourceId(sid);
          return _DemoSource(id: sid, url: url, subtitles: subs);
        }
      }
    }
    return null;
  }

  Future<_DemoSource?> _fetchWatchNowSource(int id) async {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/api/Movie/GetWatchNowMovieByID/watchNow/$id');
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    if (body is Map) {
      final url = body['sourceUrl'] ?? body['url'] ?? body['movieUrl'];
      final id0 = body['sourceID'] ?? body['id'];
      final sid = id0 is int ? id0 : int.tryParse('$id0');
      if (sid != null && url is String && url.isNotEmpty) {
        final subs = await _fetchSubtitlesBySourceId(sid);
        return _DemoSource(id: sid, url: url, subtitles: subs);
      }
      final many = body['data'];
      if (many is List && many.isNotEmpty) {
        final m0 = many.first;
        if (m0 is Map) {
          final u = m0['sourceUrl'] ?? m0['url'];
          final id0b = m0['sourceID'] ?? m0['id'];
          final sidb = id0b is int ? id0b : int.tryParse('$id0b');
          if (sidb != null && u is String && u.isNotEmpty) {
            final subs = await _fetchSubtitlesBySourceId(sidb);
            return _DemoSource(id: sidb, url: u, subtitles: subs);
          }
        }
      }
    }
    return null;
  }

  Future<List<Map<String, String>>> _fetchSubtitlesBySourceId(
      int sourceId) async {
    try {
      final url = Uri.parse(
          '${AppConstants.baseApiUrl}/api/MovieSubTitle/GetAllSubTitlesByMovieId/movie/GetAllSubTitlesBySourceID/$sourceId');
      final res = await http.get(url);
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      List<dynamic> list = [];
      if (body is Map && body['data'] is List) {
        list = (body['data'] as List);
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
          final idVal = sub['movieSubTitleID'] ?? sub['MovieSubTitleID'] ?? sub['subTitleID'] ?? sub['id'];
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
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        _subtitleCues = _parseSrtOrVttToChewie(res.body);
        if (_subtitleCues.isNotEmpty) {
          final first = _subtitleCues.first;
          final last = _subtitleCues.last;
          // Basic diagnostics to verify parsing in web console
          // ignore: avoid_print
          print('Subtitles loaded: ${_subtitleCues.length} cues from '+url);
          // ignore: avoid_print
          print('First cue: ${first.start} -> ${first.end}');
          // ignore: avoid_print
          print('Last cue: ${last.start} -> ${last.end}');
        } else {
          // ignore: avoid_print
          print('Subtitles parse produced 0 cues for '+url);
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
    if (lines.isNotEmpty && lines.first.trim().toUpperCase().startsWith('WEBVTT')) {
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
    setState(() { _uiVisible = true; });
    _scheduleHideUI();
  }

  void _scheduleHideUI() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() { _uiVisible = false; });
      }
    });
  }

  void _showUI() {
    if (!_uiVisible) {
      setState(() { _uiVisible = true; });
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
                    const Text('Now Playing',
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
                  aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
                  child: Stack(
                    children: [
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: Colors.white70)))
                              : (_chewieController != null
                                  ? Chewie(controller: _chewieController!)
                                  : const SizedBox.shrink()),
                      // Custom dropdown settings (playback speed + subtitles)
                      if (_uiVisible || (_chewieController?.isFullScreen ?? false)) Positioned(
                        right: 88,
                        bottom: 8,
                        child: PopupMenuButton<String>(
                          tooltip: 'Settings',
                          color: Colors.black87,
                          icon: const Icon(Icons.settings, color: Colors.white),
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
                                  Icon(Icons.speed, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Text('Playback speed',
                                      style: TextStyle(color: Colors.white)),
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
                                      style: TextStyle(color: Colors.white)),
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
          '${AppConstants.baseApiUrl}/api/Comment/GetCommentsByMovieID/${widget.movieId}?movieID=${widget.movieId}');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = (body is Map<String, dynamic>)
            ? (body['data'] ?? body['Data'] ?? body)
            : body;
        final list = (data is List ? data : [])
            .map((e) => CommentDemo.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _comments = list;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch comments';
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

  Future<void> _post({required String text, int? parentId}) async {
    final info = currentUserInfo.value;
    final logged = isLoggedIn.value;
    if (!logged || info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment')));
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
      final res = await http.post(uri,
          headers: {'Content-Type': 'application/json'}, body: body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _composer.clear();
        setState(() {
          _replyingTo = null;
        });
        await _loadComments();
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 18)),
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
                enabled: isLoggedIn.value && !_posting,
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
                  child: Text(
                      (c.userName?.isNotEmpty == true ? c.userName![0] : 'U')
                          .toUpperCase())),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.userName ?? 'User',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(_formatDate(c.createdAt),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
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
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                  radius: 14,
                  child: Text(
                      (r.userName?.isNotEmpty == true ? r.userName![0] : 'U')
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.userName ?? 'User',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(_formatDate(r.createdAt),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
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
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              isLoggedIn.value = false;
              currentUserInfo.value = null;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Logged out')));
              context.go('/');
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
    final nameCtrl = TextEditingController(text: info['userName'] ?? '');
    String gender = info['gender'] ?? 'other';
    final bioCtrl = TextEditingController(text: info['bio'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: gender.isNotEmpty ? gender : 'other',
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => gender = v ?? 'other',
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final updated = {
                ...info,
                'userName': nameCtrl.text.trim(),
                'gender': gender,
                'bio': bioCtrl.text.trim(),
              };
              currentUserInfo.value = Map<String, String>.from(
                  updated.map((k, v) => MapEntry(k, v?.toString() ?? '')));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated')));
            },
            child: const Text('Save'),
          )
        ],
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
            final email = info?['email'] ?? 'Not signed in';
            final gender = info?['gender'] ?? '—';
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
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.red,
                                  child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(email,
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.grey[900],
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Latest Comments',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                SizedBox(height: 8),
                                Text('Coming soon'),
                              ],
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
                        Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: () =>
                                      _showEditProfileDialog(context),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit Profile'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Preferences',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                SizedBox(height: 8),
                                Text(
                                    'Notification and theme preferences will be added later.'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Danger Zone',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.delete_forever,
                                      color: Colors.red),
                                  label: const Text('Delete Account'),
                                ),
                              ],
                            ),
                          ),
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
      // Load prices
      final pricesRes =
          await http.get(Uri.parse('${AppConstants.baseApiUrl}/api/price/all'));
      List<dynamic> prices = [];
      if (pricesRes.statusCode >= 200 && pricesRes.statusCode < 300) {
        final body = json.decode(pricesRes.body);
        prices = body is Map<String, dynamic>
            ? (body['data'] ?? body['Data'] ?? [])
            : (body as List? ?? []);
      }

      // Load plans
      final plansRes =
          await http.get(Uri.parse('${AppConstants.baseApiUrl}/api/plans/all'));
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
        final subsRes = await http.get(Uri.parse(
            '${AppConstants.baseApiUrl}/api/payment/subscription/user/$userId'));
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
                final priceRes = await http.get(Uri.parse(
                    '${AppConstants.baseApiUrl}/api/price/${latest['priceID']}'));
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
                final planRes = await http.get(Uri.parse(
                    '${AppConstants.baseApiUrl}/api/plans/${planId}'));
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
          }
        }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please sign in to subscribe')));
          context.go('/signin');
        }
        return;
      }
      final uri =
          Uri.parse('${AppConstants.baseApiUrl}/api/payment/vnpay/checkout');
      final res = await http.post(
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
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Checkout failed (${res.statusCode})');
      }
      final body = json.decode(res.body);
      final payUrl = body['payUrl'] ?? body['PayUrl'];
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Checkout error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_error != null)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Failed to load subscription info: $_error'),
                ),
              ),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Plan',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_loading && _currentPlan == null)
                      const Text('Loading...')
                    else if (_currentPlan == null)
                      const Text('No active subscription')
                    else ...[
                      Text(_currentPlan!['name'] ?? 'Current Plan'),
                      const SizedBox(height: 4),
                      Text('Status: ${_currentPlan!['status'] ?? 'N/A'}'),
                      if (_currentPlan!['expiry'] != null)
                        Text('Expires: ${_currentPlan!['expiry']}'),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Plans',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                        'Unlock VIP perks like ad-free viewing and HD streaming.',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    if (_loading && _plans.isEmpty)
                      const Text('Loading...')
                    else if (_plans.isEmpty)
                      const Text('No active plans available.')
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _plans.map((p) {
                          final pid = (p['id'] ?? '').toString();
                          final priceInfo = _planPriceInfo[pid];
                          final price = priceInfo == null
                              ? (_planPriceLabel[pid] ?? 'N/A')
                              : _formatAmount(
                                  priceInfo['amount'], priceInfo['currency']);
                          final intervalUnit =
                              (priceInfo?['intervalUnit'] ?? 'month')
                                  .toString();
                          final intervalCount = int.tryParse(
                                  (priceInfo?['intervalCount'] ?? 1)
                                      .toString()) ??
                              1;
                          final amountNum = priceInfo != null
                              ? double.tryParse(
                                  priceInfo['amount']?.toString() ?? '')
                              : null;
                          final isFree =
                              (amountNum != null && amountNum == 0) ||
                                  ((_planPriceLabel[pid] ?? '') == 'Free');
                          final isCurrent =
                              (_currentPlan?['planId']?.toString() ?? '') ==
                                  pid;
                          return SizedBox(
                            width: 260,
                            child: Card(
                              elevation: 0,
                              color: Colors.grey[900],
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'] ?? 'Plan',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16)),
                                    const SizedBox(height: 6),
                                    Text(
                                        '$price / ${intervalCount > 1 ? '$intervalCount ' : ''}$intervalUnit',
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                    if (p['description'] != null) ...[
                                      const SizedBox(height: 6),
                                      Text(p['description'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                    const SizedBox(height: 8),
                                    const Text(
                                        '• Ad-free viewing\n• HD streaming\n• Early access',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 8),
                                    if (!isCurrent && !isFree)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: FilledButton(
                                          onPressed:
                                              _planFirstPriceId[pid] == null
                                                  ? null
                                                  : () => _startCheckout(
                                                      _planFirstPriceId[pid]!),
                                          child: const Text('Upgrade'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Billing History',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('Coming soon'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.cancel),
                    SizedBox(width: 8),
                    Text('Cancel Subscription'),
                    SizedBox(width: 12),
                    Text('Coming soon'),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        isLoggedIn.value = true;
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
  String? _error;

  void _submit() {
    if (!_emailController.text.contains('@')) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    context.go('/check-email');
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
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Send reset link'),
              ),
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
