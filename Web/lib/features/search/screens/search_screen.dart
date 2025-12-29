import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/movie_model.dart';
import '../../movies/providers/movie_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _controller = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchMoviesProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _query = '';
                _controller.clear();
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search movies...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: resultsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to search: $e')),
                data: (movies) {
                  if (movies.isEmpty) {
                    return const Center(child: Text('No results'));
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.66,
                    ),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      return _SearchResultCard(movie: movie);
                    },
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

class _SearchResultCard extends StatelessWidget {
  final Movie movie;
  const _SearchResultCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    final genres = movie.genreNames; // from MovieTag.tagName via API
    return GestureDetector(
      onTap: () => context.push('/movie/${movie.movieId}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              movie.mainImageUrl,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: genres.take(3).map((g) => _GenreChip(label: g)).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  const _GenreChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}