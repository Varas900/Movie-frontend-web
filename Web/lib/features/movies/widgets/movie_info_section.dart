import 'package:flutter/material.dart';

import '../../../core/models/movie_model.dart';

class MovieInfoSection extends StatelessWidget {
  final Movie movie;

  const MovieInfoSection({
    super.key,
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and Year (Mobile fallback)
        if (MediaQuery.of(context).size.width <= 1024) ...[
          Text(
            movie.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Rating and Duration
        Row(
          children: [
            if (movie.imdbRating != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      movie.imdbRating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            if ((movie.durationSeconds ?? 0) > 0) ...[
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${movie.durationSeconds}s',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
            ],
            
            if (movie.year != null) ...[
              Text(
                movie.year.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Genres
        if (movie.genreNames.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: movie.genreNames.map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  genre,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        
        // Plot/Overview
        if (movie.plot?.isNotEmpty == true) ...[
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.plot!,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 16),
        ],
        
        // Additional Information
        _buildAdditionalInfo(context),
      ],
    );
  }

  Widget _buildAdditionalInfo(BuildContext context) {
    final infoItems = <Widget>[];

    // Director
    if (movie.director?.isNotEmpty == true) {
      infoItems.add(_buildInfoRow(
        context,
        'Director',
        movie.director!,
        Icons.person,
      ));
    }

    // Writer
    if (movie.writer?.isNotEmpty == true) {
      infoItems.add(_buildInfoRow(
        context,
        'Writer',
        movie.writer!,
        Icons.edit,
      ));
    }

    // Country
    if (movie.country?.isNotEmpty == true) {
      infoItems.add(_buildInfoRow(
        context,
        'Country',
        movie.country!,
        Icons.public,
      ));
    }

    // Language
    if (movie.language?.isNotEmpty == true) {
      infoItems.add(_buildInfoRow(
        context,
        'Language',
        movie.language!,
        Icons.language,
      ));
    }

    // Awards
    if (movie.awards?.isNotEmpty == true) {
      infoItems.add(_buildInfoRow(
        context,
        'Awards',
        movie.awards!,
        Icons.emoji_events,
      ));
    }

    // Box Office
    if (movie.boxOffice?.isNotEmpty == true) {
      infoItems.add(_buildInfoRow(
        context,
        'Box Office',
        movie.boxOffice!,
        Icons.attach_money,
      ));
    }

    // Production
    if (movie.production?.isNotEmpty == true) {
      infoItems.add(_buildInfoRow(
        context,
        'Production',
        movie.production!,
        Icons.movie,
      ));
    }

    if (infoItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...infoItems,
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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