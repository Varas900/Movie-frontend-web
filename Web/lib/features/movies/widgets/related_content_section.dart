import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/movie_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/image_with_placeholder.dart';
import '../providers/movie_provider.dart';

class RelatedContentSection extends ConsumerWidget {
  final int movieId;
  final List<String> genres;

  const RelatedContentSection({
    super.key,
    required this.movieId,
    required this.genres,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedMoviesAsync = ref.watch(relatedMoviesProvider(movieId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Like This',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        relatedMoviesAsync.when(
          loading: () => _buildLoadingGrid(),
          error: (error, stack) => _buildErrorWidget(context, ref),
          data: (movies) => _buildMoviesGrid(context, movies),
        ),
      ],
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref) {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load related content',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.refresh(relatedMoviesProvider(movieId));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoviesGrid(BuildContext context, List<Movie> movies) {
    if (movies.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.movie_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No related content found',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (screenWidth > 1200) {
      crossAxisCount = 6;
    } else if (screenWidth > 800) {
      crossAxisCount = 4;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: movies.length > 12 ? 12 : movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return _buildMovieCard(context, movie);
      },
    );
  }

  Widget _buildMovieCard(BuildContext context, Movie movie) {
    return GestureDetector(
      onTap: () {
        context.push('${AppRoutes.movieDetails}/${movie.movieId}');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Movie Poster
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: MoviePosterImage(
                  imageUrl: movie.image,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            
            // Movie Info
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Expanded(
                      child: Text(
                        movie.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Rating and Year
                    Row(
                      children: [
                        if (movie.imdbRating != null) ...[
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            movie.imdbRating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const Spacer(),
                        if (movie.year != null)
                          Text(
                            movie.year.toString(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
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