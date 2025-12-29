import 'package:flutter/material.dart';

class ContinueWatchingContent extends StatelessWidget {
  const ContinueWatchingContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Continue Watching',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick up where you left off',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to continue watching
              },
              child: const Text('View All'),
            ),
          ],
        ),
      ),
    );
  }
}