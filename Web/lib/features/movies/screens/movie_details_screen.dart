import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/models/movie_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/utils/authz_prompt.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/image_with_placeholder.dart';
import '../providers/movie_provider.dart';
import '../widgets/movie_info_section.dart';
import '../widgets/cast_section.dart';
import '../widgets/related_content_section.dart';
import '../widgets/reviews_section.dart';
import '../widgets/comments_section.dart';
import '../widgets/user_rating_section.dart';
import '../../player/widgets/player_dialog.dart';
import '../providers/saved_movies_provider.dart';

class MovieDetailsScreen extends ConsumerStatefulWidget {
  final int movieId;

  const MovieDetailsScreen({
    super.key,
    required this.movieId,
  });

  @override
  ConsumerState<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends ConsumerState<MovieDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  List<MovieTag>? _tags;
  bool _loadingTags = false;

  bool _loadingEpisodes = false;
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
    _scrollController.addListener(_onScroll);
    _fetchTags(widget.movieId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, String> _authHeaders() {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = StorageService.getUserToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  Future<void> _fetchEpisodesIfNeeded(int movieId) async {
    if (_episodesForMovieId == movieId) {
      if (_loadingEpisodes && _episodesLoadTask != null) {
        await _episodesLoadTask;
        return;
      }
      if (_episodes.isNotEmpty || _episodesError != null) return;
    }

    final completer = Completer<void>();
    _episodesLoadTask = completer.future;

    setState(() {
      _loadingEpisodes = true;
      _episodesError = null;
      _episodesForMovieId = movieId;
      _episodes = const [];
    });
    try {
      final uri = Uri.parse(
          '${AppConstants.baseApiUrl}/api/Episode/GetEpisodesByMovieId/getbyMovie/$movieId');
      final res = await http.get(uri, headers: _authHeaders());
      if (res.statusCode != 200) {
        throw Exception('Episodes HTTP ${res.statusCode}');
      }
      final decoded = jsonDecode(res.body);
      final data = decoded is Map<String, dynamic>
          ? (decoded['data'] ?? decoded['Data'] ?? decoded)
          : decoded;
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
      final seasons = eps
          .map((e) =>
              (e['seasonNumber'] as num?)?.toInt() ??
              (e['season'] as num?)?.toInt() ??
              0)
          .where((s) => s > 0)
          .toSet()
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        if (seasons.isNotEmpty &&
            (_selectedSeason == null || !seasons.contains(_selectedSeason))) {
          _selectedSeason = seasons.first;
        }
        _loadingEpisodes = false;
      });
      completer.complete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingEpisodes = false;
          _episodesError = e.toString();
        });
      }
      completer.complete();
    } finally {
      _episodesLoadTask = null;
    }
  }

  Future<void> _fetchTags(int movieId) async {
    setState(() {
      _loadingTags = true;
    });
    try {
      // 1) Fetch all tags
      final tagsUri = Uri.parse(
          '${AppConstants.baseApiUrl}/movie/Tag/GetAllTags/getALlTags');
      final tagsRes = await http.get(tagsUri);
      if (tagsRes.statusCode != 200) {
        setState(() {
          _loadingTags = false;
        });
        return;
      }
      final tagsBody = jsonDecode(tagsRes.body);
      final tagsData = tagsBody is Map<String, dynamic>
          ? (tagsBody['data'] ?? tagsBody['Data'] ?? [])
          : tagsBody;
      final allTags = <MovieTag>[];
      if (tagsData is List) {
        for (final t in tagsData) {
          if (t is Map<String, dynamic>) {
            final tag = MovieTag.fromJson(t);
            allTags.add(tag);
          }
        }
      }

      // 2) For each tag, check if movie belongs by calling movies-by-tag endpoint
      final matched = <MovieTag>[];
      for (final tag in allTags) {
        final mapUri = Uri.parse(
            '${AppConstants.baseApiUrl}/movie/MovieTag/GetMoviesByTagIDs/getMovieByTagID?tagID=${tag.tagId}');
        final mapRes = await http.get(mapUri);
        if (mapRes.statusCode != 200) continue;
        final mBody = jsonDecode(mapRes.body);
        final mData = mBody is Map<String, dynamic>
            ? (mBody['data'] ?? mBody['Data'] ?? [])
            : mBody;
        if (mData is List) {
          final contains = mData.any((item) {
            if (item is Map<String, dynamic>) {
              final id = (item['movieID'] as num?)?.toInt();
              return id == movieId;
            }
            return false;
          });
          if (contains) matched.add(tag);
        }
      }

      setState(() {
        _tags = matched;
        _loadingTags = false;
      });
    } catch (e) {
      setState(() {
        _loadingTags = false;
      });
    }
  }

  void _onScroll() {
    const showAppBarOffset = 300.0;
    if (_scrollController.offset > showAppBarOffset && !_showAppBarTitle) {
      setState(() {
        _showAppBarTitle = true;
      });
    } else if (_scrollController.offset <= showAppBarOffset &&
        _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final movieAsync = ref.watch(movieDetailsProvider(widget.movieId));
    // final isFavorite = ref.watch(isFavoriteProvider(widget.movieId));

    return Scaffold(
      body: Column(
        children: [
          // Custom App Header with movie title when scrolled
          AppHeader(
            showSearchBar: !_showAppBarTitle,
          ),

          // Main Content
          Expanded(
            child: movieAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load movie details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.refresh(movieDetailsProvider(widget.movieId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (movie) {
                final enriched = (movie.tags != null && movie.tags!.isNotEmpty)
                    ? movie
                    : (_tags != null && _tags!.isNotEmpty
                        ? movie.copyWith(tags: _tags)
                        : movie);
                if (enriched.isSeries) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _fetchEpisodesIfNeeded(enriched.movieId);
                  });
                }
                return _buildMovieDetails(enriched);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieDetails(Movie movie) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section with Backdrop and Poster
          _buildHeroSection(movie),

          // Movie Information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MovieInfoSection(movie: movie),

                const SizedBox(height: 32),

                // Action Buttons
                _buildActionButtons(movie),

                const SizedBox(height: 32),

                // Cast & Crew
                if (movie.actors?.isNotEmpty == true) ...[
                  CastSection(actors: movie.actors!),
                  const SizedBox(height: 32),
                ],

                // Episodes (Series only)
                if (movie.isSeries) ...[
                  _buildEpisodesSection(movie),
                  const SizedBox(height: 32),
                ],

                // Reviews
                ReviewsSection(movieId: movie.movieId),

                const SizedBox(height: 32),

                // Related Content
                RelatedContentSection(
                  movieId: movie.movieId,
                  genres: movie.genreNames,
                ),

                const SizedBox(height: 32),
                UserRatingSection(movieId: movie.movieId),

                const SizedBox(height: 32),
                CommentsSection(movieId: movie.movieId),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesSection(Movie movie) {
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
        ? (_selectedSeason != null && seasons.contains(_selectedSeason)
            ? _selectedSeason
            : seasons.first)
        : null;

    final filtered = _episodes.where((e) {
      final season = (e['seasonNumber'] as num?)?.toInt() ??
          (e['season'] as num?)?.toInt() ??
          0;
      return selected == null || season == selected;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Episodes',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              'Seasons:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selected,
                  icon: Icon(Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.primary),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: seasons
                      .map((s) => DropdownMenuItem<int>(
                            value: s,
                            child: Text('Season $s'),
                          ))
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
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loadingEpisodes)
          const Center(child: CircularProgressIndicator())
        else if (_episodesError != null)
          Text(
            _episodesError!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else if (filtered.isEmpty)
          Text(
            'No episodes available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ep = filtered[index];
              final epId = (ep['episodeID'] as num?)?.toInt() ??
                  (ep['episodeId'] as num?)?.toInt() ??
                  (ep['id'] as num?)?.toInt() ??
                  0;
              final epTitle =
                  (ep['title'] as String?)?.trim().isNotEmpty == true
                      ? (ep['title'] as String)
                      : 'Episode $epId';
              final synopsis = (ep['synopsis'] as String?)?.trim();
              final description = (ep['description'] as String?)?.trim() ??
                  (ep['overview'] as String?)?.trim();
              final durationSeconds = (ep['durationSeconds'] as num?)?.toInt();
              final episodeNumber = (ep['episodeNumber'] as num?)?.toInt() ??
                  (ep['episode'] as num?)?.toInt();
              final epLabel =
                  episodeNumber != null ? 'Episode $episodeNumber' : 'Episode';

              return InkWell(
                onTap: epId <= 0
                    ? null
                    : () {
                        context.go(
                            '${AppRoutes.player}/${movie.movieId}?type=series&episode=$epId');
                      },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    epLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                Text(
                                  durationSeconds != null
                                      ? '${durationSeconds}s'
                                      : '—s',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              epTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (synopsis != null && synopsis.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                synopsis,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                            if (description != null &&
                                description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHeroSection(Movie movie) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Container(
      height: isDesktop ? 500 : 400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop Image
          BannerImage(
            imageUrl: movie.primaryImageUrl,
            height: isDesktop ? 500 : 400,
            width: double.infinity,
          ),

          // Content Overlay
          Container(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Movie Poster (Desktop)
                if (isDesktop) ...[
                  MoviePosterImage(
                    imageUrl: movie.image,
                    width: 200,
                    height: 300,
                  ),
                  const SizedBox(width: 24),
                ],

                // Movie Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating Badge
                      if (movie.rated != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            movie.rated!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Title
                      Text(
                        movie.title,
                        style: TextStyle(
                          fontSize: isDesktop ? 48 : 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Metadata
                      Wrap(
                        spacing: 16,
                        children: [
                          if (movie.year != null)
                            Text(
                              movie.year.toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          if ((movie.durationSeconds ?? 0) > 0)
                            Text(
                              '${movie.durationSeconds}s',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          if (movie.genreNames.isNotEmpty)
                            Text(
                              movie.genreNames.take(3).join(', '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Back Button
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: () => context.goBack(),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Movie movie) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final isSaved = ref.watch(isSavedMovieProvider(movie.movieId));

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Watch Now Button
        ElevatedButton.icon(
          onPressed: () async {
            if (movie.isSeries) {
              await _fetchEpisodesIfNeeded(movie.movieId);
              final firstEpId = _firstEpisodeIdFromLoaded();
              if (firstEpId != null) {
                if (!mounted) return;
                context.go(
                    '${AppRoutes.player}/${movie.movieId}?type=series&episode=$firstEpId');
                return;
              }
            }
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => PlayerDialog(movieId: movie.movieId),
            );
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Watch Now'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),

        // Play Trailer Button
        OutlinedButton.icon(
          onPressed: () {
            // Play trailer logic
          },
          icon: const Icon(Icons.movie),
          label: const Text('Play Trailer'),
        ),

        // My List (MovieBox)
        OutlinedButton.icon(
          onPressed: () async {
            if (!isAuthenticated) {
              await showAuthzPromptDialog(
                context,
                type: AuthzPromptType.signIn,
                onPrimary: () => context.go(AppRoutes.signin),
              );
              return;
            }
            final notifier = ref.read(savedMoviesProvider.notifier);
            try {
              if (isSaved) {
                await notifier.remove(movie.movieId);
              } else {
                await notifier.add(movie.movieId);
              }
            } catch (e) {
              final prompt = authzPromptFromError(e);
              if (prompt == AuthzPromptType.signIn) {
                if (!context.mounted) return;
                await showAuthzPromptDialog(
                  context,
                  type: AuthzPromptType.signIn,
                  onPrimary: () async {
                    await ref.read(authProvider.notifier).signOut();
                    if (context.mounted) context.go(AppRoutes.signin);
                  },
                );
                return;
              }
              if (prompt == AuthzPromptType.buyPlan) {
                if (!context.mounted) return;
                await showAuthzPromptDialog(
                  context,
                  type: AuthzPromptType.buyPlan,
                  onPrimary: () => context.go('${AppRoutes.profile}?tab=subscription'),
                );
                return;
              }
              rethrow;
            }
          },
          icon: Icon(
            isSaved ? Icons.check : Icons.add,
          ),
          label: Text(
            isSaved ? 'Saved' : 'My List',
          ),
        ),

        // Download Button (if premium user)
        OutlinedButton.icon(
          onPressed: () {
            // Download logic
          },
          icon: const Icon(Icons.download),
          label: const Text('Download'),
        ),

        // Share Button
        OutlinedButton.icon(
          onPressed: () {
            // Share logic
          },
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
      ],
    );
  }
}
