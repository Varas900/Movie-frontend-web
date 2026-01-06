import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/movie_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/image_with_placeholder.dart';

class CastSection extends StatelessWidget {
  final List<MovieActor> actors;

  const CastSection({
    super.key,
    required this.actors,
  });

  @override
  Widget build(BuildContext context) {
    if (actors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cast & Crew',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (actors.length > 5)
              TextButton(
                onPressed: () {
                  _showAllCast(context);
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: actors.length > 10 ? 10 : actors.length,
            itemBuilder: (context, index) {
              final actor = actors[index];
              return _buildCastCard(context, actor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCastCard(BuildContext context, MovieActor actor) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          context.push('${AppRoutes.actorDetails}/${actor.personId}');
        },
        child: Column(
          children: [
            // Actor Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: ActorAvatarImage(
                  imageUrl: actor.avatar,
                  radius: 40,
                  fallbackText: actor.fullName
                      .split(' ')
                      .where((e) => e.isNotEmpty)
                      .map((e) => e[0])
                      .take(2)
                      .join(),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Actor Name
            Text(
              actor.fullName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Character Name
            if (actor.characterName?.isNotEmpty == true)
              Text(
                actor.characterName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  void _showAllCast(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Full Cast & Crew',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Cast Grid
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: actors.length,
                    itemBuilder: (context, index) {
                      final actor = actors[index];
                      return _buildFullCastCard(context, actor);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullCastCard(BuildContext context, MovieActor actor) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        context.push('${AppRoutes.actorDetails}/${actor.personId}');
      },
      child: Column(
        children: [
          // Actor Image
          Expanded(
            flex: 3,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageWithPlaceholder(
                  imageUrl: actor.avatar,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Actor Info
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Actor Name
                Text(
                  actor.fullName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Character Name
                if (actor.characterName?.isNotEmpty == true)
                  Text(
                    actor.characterName!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
