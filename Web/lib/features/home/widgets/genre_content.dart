import 'package:flutter/material.dart';

class GenreContent extends StatelessWidget {
  final String genre;

  const GenreContent({
    super.key,
    required this.genre,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_filter,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Browse $genre Movies',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Discover the best $genre content',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to genre screen
              },
              child: Text('Explore $genre'),
            ),
          ],
        ),
      ),
    );
  }
}