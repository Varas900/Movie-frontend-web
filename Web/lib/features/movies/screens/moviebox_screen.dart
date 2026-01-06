import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/movie_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/image_with_placeholder.dart';
import '../providers/saved_movies_provider.dart';

enum _MovieBoxSort { dateAdded, title, rating }

class MovieBoxScreen extends ConsumerStatefulWidget {
  const MovieBoxScreen({super.key});

  @override
  ConsumerState<MovieBoxScreen> createState() => _MovieBoxScreenState();
}

class _MovieBoxScreenState extends ConsumerState<MovieBoxScreen> {
  _MovieBoxSort _sort = _MovieBoxSort.dateAdded;
  final Map<int, Movie> _cache = <int, Movie>{};
  final Set<int> _loading = <int>{};

  @override
  void initState() {
    super.initState();
    ref.listenManual(savedMoviesProvider, (prev, next) {
      final ids = next.value?.movieIds ?? <int>{};
      _ensureLoaded(ids);
      if (mounted) {
        setState(() {
          _cache.removeWhere((key, _) => !ids.contains(key));
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(savedMoviesProvider.notifier).refresh();
    });
  }

  void _ensureLoaded(Set<int> ids) {
    for (final id in ids) {
      if (_cache.containsKey(id) || _loading.contains(id)) continue;
      _loading.add(id);
      _loadOne(id);
    }
  }

  Future<void> _loadOne(int movieId) async {
    try {
      final api = ref.read(apiServiceProvider);
      final movie = await api.getMovieDetails(movieId);
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

  List<int> _sortedIds(SavedMoviesState data) {
    final list = data.movieIds.toList();
    list.sort((a, b) {
      switch (_sort) {
        case _MovieBoxSort.title:
          final ta = (_cache[a]?.title ?? '').toLowerCase();
          final tb = (_cache[b]?.title ?? '').toLowerCase();
          return ta.compareTo(tb);
        case _MovieBoxSort.rating:
          final ra = _cache[a]?.popularity ?? 0;
          final rb = _cache[b]?.popularity ?? 0;
          return rb.compareTo(ra);
        case _MovieBoxSort.dateAdded:
          final da = data.createdAtByMovieId[a];
          final db = data.createdAtByMovieId[b];
          return (db ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(da ?? DateTime.fromMillisecondsSinceEpoch(0));
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final savedAsync = ref.watch(savedMoviesProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(showSearchBar: false),
          Expanded(
            child: savedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 56),
                    const SizedBox(height: 12),
                    Text('Failed to load MovieBox',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(e.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(savedMoviesProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
              data: (data) {
                final sorted = _sortedIds(data);
                if (sorted.isEmpty) {
                  return _EmptyMovieBox(onBrowse: () => context.go(AppRoutes.home));
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          'MovieBox',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${sorted.length} movies saved',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ChoiceChip(
                              label: const Text('Date Added'),
                              selected: _sort == _MovieBoxSort.dateAdded,
                              onSelected: (_) =>
                                  setState(() => _sort = _MovieBoxSort.dateAdded),
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
                                final movieId = sorted[index];
                                final movie = _cache[movieId];
                                return _MovieBoxCard(
                                  movieId: movieId,
                                  movie: movie,
                                  onOpen: () =>
                                      context.push('${AppRoutes.movieDetails}/$movieId'),
                                  onRemove: () async {
                                    try {
                                      await ref
                                          .read(savedMoviesProvider.notifier)
                                          .remove(movieId);
                                    } catch (_) {
                                      if (!context.mounted) return;
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
          ),
        ],
      ),
    );
  }
}

class _EmptyMovieBox extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyMovieBox({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border,
                  size: 84, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
              const SizedBox(height: 14),
              Text(
                'Your MovieBox is empty',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Save movies to watch later.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onBrowse,
                  child: const Text('Browse Movies'),
                ),
              ),
            ],
          ),
        ),
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
    final year = movie?.year?.toString() ?? '—';
    final imageUrl = movie?.image;
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
              if (imageUrl != null && imageUrl.isNotEmpty)
                ImageWithPlaceholder(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                )
              else
                Container(color: Theme.of(context).colorScheme.surface),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          score.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
