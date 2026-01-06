import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/storage_service.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/utils/authz_prompt.dart';
import '../../../shared/widgets/image_with_placeholder.dart';

class ActorDetailsScreen extends StatefulWidget {
  final int actorId;

  const ActorDetailsScreen({
    super.key,
    required this.actorId,
  });

  @override
  State<ActorDetailsScreen> createState() => _ActorDetailsScreenState();
}

class _ActorDetailsScreenState extends State<ActorDetailsScreen> {
  late Future<_ActorDetailsVm> _future;

  String _formatDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';
    final dt = DateTime.tryParse(iso.trim());
    if (dt == null) return iso.trim();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Map<String, String> _authHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = StorageService.getUserToken();
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body['data'] ?? body['Data'] ?? body['result'] ?? body;
    }
    return body;
  }

  Future<_ActorDetailsVm> _load() async {
    final actor0 = await _fetchActor(widget.actorId);
    final actor = await _hydrateRegionIfNeeded(actor0);
    final movies = await _fetchMoviesByActor(widget.actorId);
    return _ActorDetailsVm(actor: actor, movies: movies);
  }

  Future<_ActorVm> _hydrateRegionIfNeeded(_ActorVm actor) async {
    if ((actor.region != null && actor.region!.trim().isNotEmpty) ||
        (actor.regionId ?? 0) <= 0) {
      return actor;
    }
    try {
      final name = await _fetchRegionName(actor.regionId!);
      if (name == null || name.trim().isEmpty) return actor;
      return _ActorVm(
        id: actor.id,
        name: actor.name,
        avatarUrl: actor.avatarUrl,
        regionId: actor.regionId,
        region: name.trim(),
        biography: actor.biography,
        birthDateLabel: actor.birthDateLabel,
      );
    } catch (_) {
      return actor;
    }
  }

  Future<String?> _fetchRegionName(int regionId) async {
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/Region/GetRegionByID/$regionId');
    final res = await http.get(uri, headers: _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = jsonDecode(res.body);
    final data = _unwrap(body);
    if (data is! Map<String, dynamic>) return null;
    return (data['regionName'] as String?)?.trim() ??
        (data['RegionName'] as String?)?.trim() ??
        (data['name'] as String?)?.trim();
  }

  Future<_ActorVm> _fetchActor(int actorId) async {
    // Mobile uses: GET /movie/Person/GetPersonById/{personId}
    // Backend controller action name is GetPersonByID; route is case-insensitive.
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/Person/GetPersonByID/$actorId');
    final res = await http.get(uri, headers: _authHeaders());

      if (res.statusCode == 401) throw Exception('HTTP_401');
      if (res.statusCode == 403) throw Exception('HTTP_403');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to load actor (HTTP ${res.statusCode})');
    }

    final body = jsonDecode(res.body);
    final data = _unwrap(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected actor response shape');
    }

    final fullName = ((data['fullName'] ?? data['FullName']) as String?)?.trim();

    final regionId = (data['regionID'] as num?)?.toInt() ??
        (data['regionId'] as num?)?.toInt() ??
        (data['RegionID'] as num?)?.toInt() ??
        (data['RegionId'] as num?)?.toInt();

    Map<String, dynamic>? nestedRegion;
    if (data['region'] is Map) {
      nestedRegion = (data['region'] as Map).cast<String, dynamic>();
    } else if (data['Region'] is Map) {
      nestedRegion = (data['Region'] as Map).cast<String, dynamic>();
    }

    final regionFromNested = nestedRegion == null
      ? null
      : ((nestedRegion['regionName'] ?? nestedRegion['RegionName'])
          as String?)
        ?.trim();

    final regionName = (data['regionName'] as String?)?.trim() ??
      (data['RegionName'] as String?)?.trim() ??
      regionFromNested ??
      (data['nationality'] as String?)?.trim();

    final biography = (data['biography'] as String?)?.trim() ??
      (data['Biography'] as String?)?.trim() ??
      (data['bio'] as String?)?.trim() ??
      (data['description'] as String?)?.trim();

    final birthDateRaw = (data['birthDate'] ??
          data['BirthDate'] ??
        data['dateOfBirth'] ??
          data['DateOfBirth'] ??
        data['dob'] ??
        data['birthday'])
      ?.toString()
      .trim();

    return _ActorVm(
      id: (data['personID'] as num?)?.toInt() ??
          (data['personId'] as num?)?.toInt() ??
          (data['PersonID'] as num?)?.toInt() ??
          (data['PersonId'] as num?)?.toInt() ??
          actorId,
      name: (fullName == null || fullName.isEmpty) ? 'Unknown' : fullName,
      avatarUrl: (data['avatar'] as String?)?.trim(),
      regionId: regionId,
      region: (regionName == null || regionName.isEmpty) ? null : regionName,
      biography:
        (biography == null || biography.isEmpty) ? null : biography,
      birthDateLabel: _formatDate(birthDateRaw),
    );
  }

  Future<List<_ActorMovieVm>> _fetchMoviesByActor(int actorId) async {
    // Mobile uses: GET /movie/MoviePerson/GetMoviesByPerson/{personID}
    final uri = Uri.parse(
        '${AppConstants.baseApiUrl}/movie/MoviePerson/GetMoviesByPerson/$actorId');
    final res = await http.get(uri, headers: _authHeaders());

      if (res.statusCode == 401) throw Exception('HTTP_401');
      if (res.statusCode == 403) throw Exception('HTTP_403');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return [];
    }

    final body = jsonDecode(res.body);
    final data = _unwrap(body);
    final list = (data is List) ? data : const <dynamic>[];

    return list
        .whereType<Map>()
        .map((m) {
          final map = m.cast<String, dynamic>();
          final movieId = (map['movieID'] as num?)?.toInt() ??
              (map['id'] as num?)?.toInt() ??
              0;
          final title = (map['title'] as String?)?.trim() ?? 'Untitled';
          final image = (map['image'] as String?)?.trim();
          final releaseDate = map['releaseDate']?.toString();
          final year = (map['year'] as num?)?.toInt();
          final computedYear = (year != null && year > 0)
              ? year.toString()
              : (releaseDate != null && releaseDate.length >= 4
                  ? releaseDate.substring(0, 4)
                  : '—');
          final popularity = (map['popularity'] as num?)?.toDouble();
          final movieType = (map['movieType'] as String?)?.trim();
          final isSeries = (movieType ?? '').toLowerCase() == 'series' ||
              ((map['totalSeasons'] as num?)?.toInt() ?? 0) > 0;
          return _ActorMovieVm(
            movieId: movieId,
            title: title,
            imageUrl: image,
            yearLabel: computedYear,
            ratingLabel:
                popularity != null ? popularity.toStringAsFixed(1) : null,
            isSeries: isSeries,
          );
        })
        .where((m) => m.movieId > 0)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actor Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: FutureBuilder<_ActorDetailsVm>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
              final prompt = authzPromptFromError(snapshot.error);
              final msg = prompt == AuthzPromptType.signIn
                  ? 'Please sign in to view actor details.'
                  : prompt == AuthzPromptType.buyPlan
                      ? 'Please buy a plan to view actor details.'
                      : 'Failed to load actor details.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(msg, textAlign: TextAlign.center),
                      if (prompt != null) ...[
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (prompt == AuthzPromptType.signIn) {
                              context.go('/signin');
                            } else {
                              context.go('/profile?tab=subscription');
                            }
                          },
                          child: Text(authzPromptPrimaryLabel(prompt)),
                        ),
                      ],
                    ],
                  ),
              ),
            );
          }

          final data = snapshot.data!;
          final actor = data.actor;
          final movies = data.movies;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    actor.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                _ActorInfoCard(actor: actor),
                const SizedBox(height: 20),
                Text(
                  'Filmography',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _MovieGrid(movies: movies),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActorInfoCard extends StatelessWidget {
  final _ActorVm actor;

  const _ActorInfoCard({
    required this.actor,
  });

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    int? maxLines,
  }) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.25,
        );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.25,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: labelStyle,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow:
                  maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Avoid IntrinsicHeight in scroll views (can hit infinite-height assertions on web).
    // Use a smaller, bounded card height and a fixed-width photo panel (similar to the mock).
    final width = MediaQuery.sizeOf(context).width;
    final cardHeight = width >= 900
        ? 200.0
        : (width >= 600
            ? 180.0
            : 160.0);
    final imageWidth = width >= 900
        ? 170.0
        : (width >= 600
            ? 150.0
            : 130.0);
    final bioLines = width >= 900
      ? 6
      : (width >= 600
        ? 5
        : 4);

    return SizedBox(
      height: cardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: imageWidth,
              height: double.infinity,
              child: (actor.avatarUrl != null && actor.avatarUrl!.isNotEmpty)
                  ? ImageWithPlaceholder(
                      imageUrl: actor.avatarUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person,
                        size: 44,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _row(context, 'Full name:', actor.name, maxLines: 2),
                  _row(context, 'Region:', actor.region ?? '—', maxLines: 2),
                  _row(context, 'Birthdate:', actor.birthDateLabel ?? '—',
                      maxLines: 1),
                  _row(context, 'Biography:', actor.biography ?? '—',
                      maxLines: bioLines),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieGrid extends StatelessWidget {
  final List<_ActorMovieVm> movies;

  const _MovieGrid({
    required this.movies,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return Text(
        'No movies found for this actor.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: movies.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final movie = movies[index];
            return _MovieCard(movie: movie);
          },
        );
      },
    );
  }
}

class _MovieCard extends StatelessWidget {
  final _ActorMovieVm movie;

  const _MovieCard({
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        // Use push so back returns to the actor details screen.
        // Always route to movie details (clean app doesn't have /series).
        context.push('/movie/${movie.movieId}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (movie.imageUrl != null && movie.imageUrl!.isNotEmpty)
                  ? ImageWithPlaceholder(
                      imageUrl: movie.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Container(
                      width: double.infinity,
                      height: double.infinity,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (movie.ratingLabel != null) ...[
                Text(
                  movie.ratingLabel!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                movie.yearLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActorDetailsVm {
  final _ActorVm actor;
  final List<_ActorMovieVm> movies;

  const _ActorDetailsVm({
    required this.actor,
    required this.movies,
  });
}

class _ActorVm {
  final int id;
  final String name;
  final String? avatarUrl;
  final int? regionId;
  final String? region;
  final String? biography;
  final String? birthDateLabel;

  const _ActorVm({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.regionId,
    this.region,
    this.biography,
    this.birthDateLabel,
  });
}

class _ActorMovieVm {
  final int movieId;
  final String title;
  final String? imageUrl;
  final String yearLabel;
  final String? ratingLabel;
  final bool isSeries;

  const _ActorMovieVm({
    required this.movieId,
    required this.title,
    required this.imageUrl,
    required this.yearLabel,
    required this.ratingLabel,
    required this.isSeries,
  });
}
