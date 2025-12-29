import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/models/movie_model.dart';
import '../../../core/utils/app_constants.dart';
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
import '../../player/widgets/player_dialog.dart';

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

  Future<void> _fetchTags(int movieId) async {
    setState(() { _loadingTags = true; });
    try {
      // 1) Fetch all tags
      final tagsUri = Uri.parse('${AppConstants.baseApiUrl}/movie/Tag/GetAllTags/getALlTags');
      final tagsRes = await http.get(tagsUri);
      if (tagsRes.statusCode != 200) {
        setState(() { _loadingTags = false; });
        return;
      }
      final tagsBody = jsonDecode(tagsRes.body);
      final tagsData = tagsBody is Map<String, dynamic> ? (tagsBody['data'] ?? tagsBody['Data'] ?? []) : tagsBody;
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
        final mapUri = Uri.parse('${AppConstants.baseApiUrl}/movie/MovieTag/GetMoviesByTagIDs/getMovieByTagID?tagID=${tag.tagId}');
        final mapRes = await http.get(mapUri);
        if (mapRes.statusCode != 200) continue;
        final mBody = jsonDecode(mapRes.body);
        final mData = mBody is Map<String, dynamic> ? (mBody['data'] ?? mBody['Data'] ?? []) : mBody;
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

      setState(() { _tags = matched; _loadingTags = false; });
    } catch (e) {
      setState(() { _loadingTags = false; });
    }
  }

  void _onScroll() {
    const showAppBarOffset = 300.0;
    if (_scrollController.offset > showAppBarOffset && !_showAppBarTitle) {
      setState(() {
        _showAppBarTitle = true;
      });
    } else if (_scrollController.offset <= showAppBarOffset && _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final movieAsync = ref.watch(movieDetailsProvider(widget.movieId));
    final isFavorite = ref.watch(isFavoriteProvider(widget.movieId));

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
                      onPressed: () => ref.refresh(movieDetailsProvider(widget.movieId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (movie) {
                final enriched = (movie.tags != null && movie.tags!.isNotEmpty)
                    ? movie
                    : ( _tags != null && _tags!.isNotEmpty ? movie.copyWith(tags: _tags) : movie );
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
                
                // Reviews
                ReviewsSection(movieId: movie.movieId),
                
                const SizedBox(height: 32),
                
                // Related Content
                RelatedContentSection(
                  movieId: movie.movieId,
                  genres: movie.genreNames,
                ),
                
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
                          if (movie.formattedDuration.isNotEmpty)
                            Text(
                              movie.formattedDuration,
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Watch Now Button
        ElevatedButton.icon(
          onPressed: () {
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
        
        // Add to Favorites
        OutlinedButton.icon(
          onPressed: () {
            ref.read(favoritesProvider.notifier).toggleFavorite(movie.movieId);
          },
          icon: Icon(
            ref.watch(isFavoriteProvider(movie.movieId)) 
                ? Icons.favorite 
                : Icons.favorite_border,
          ),
          label: Text(
            ref.watch(isFavoriteProvider(movie.movieId))
                ? 'Remove from Favorites'
                : 'Add to Favorites',
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
