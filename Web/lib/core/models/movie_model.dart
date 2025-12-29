import 'package:json_annotation/json_annotation.dart';

part 'movie_model.g.dart';

@JsonSerializable()
class Movie {
  @JsonKey(name: 'movieID')
  final int movieId;
  
  final String slug;
  final String title;
  final String? originalTitle;
  final String? description;
  final String movieType;
  final String image;
  final String status;
  final String? releaseDate;
  final int? durationSeconds;
  final int? totalSeasons;
  final int? totalEpisodes;
  final int? year;
  final String? rated;
  final double? popularity;
  @JsonKey(name: 'regionID')
  final int regionId;
  final String createdAt;
  final String updatedAt;
  final MovieRegion? region;
  final List<MovieTag>? tags;
  final List<MovieSource>? sources;
  final List<MovieActor>? actors;
  final List<MovieImage>? images;
  final double? imdbRating;
  final String? plot;
  final String? director;
  final String? writer;
  final String? country;
  final String? language;
  final String? awards;
  final String? boxOffice;
  final String? production;
  final String? primaryImageUrl;

  const Movie({
    required this.movieId,
    required this.slug,
    required this.title,
    this.originalTitle,
    this.description,
    required this.movieType,
    required this.image,
    required this.status,
    this.releaseDate,
    this.durationSeconds,
    this.totalSeasons,
    this.totalEpisodes,
    this.year,
    this.rated,
    this.popularity,
    required this.regionId,
    required this.createdAt,
    required this.updatedAt,
    this.region,
    this.tags,
    this.sources,
    this.actors,
    this.images,
    this.imdbRating,
    this.plot,
    this.director,
    this.writer,
    this.country,
    this.language,
    this.awards,
    this.boxOffice,
    this.production,
    this.primaryImageUrl,
  });

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);
  Map<String, dynamic> toJson() => _$MovieToJson(this);

  Movie copyWith({
    int? movieId,
    String? slug,
    String? title,
    String? originalTitle,
    String? description,
    String? movieType,
    String? image,
    String? status,
    String? releaseDate,
    int? durationSeconds,
    int? totalSeasons,
    int? totalEpisodes,
    int? year,
    String? rated,
    double? popularity,
    int? regionId,
    String? createdAt,
    String? updatedAt,
    MovieRegion? region,
    List<MovieTag>? tags,
    List<MovieSource>? sources,
    List<MovieActor>? actors,
    List<MovieImage>? images,
  }) {
    return Movie(
      movieId: movieId ?? this.movieId,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      description: description ?? this.description,
      movieType: movieType ?? this.movieType,
      image: image ?? this.image,
      status: status ?? this.status,
      releaseDate: releaseDate ?? this.releaseDate,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      year: year ?? this.year,
      rated: rated ?? this.rated,
      popularity: popularity ?? this.popularity,
      regionId: regionId ?? this.regionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      region: region ?? this.region,
      tags: tags ?? this.tags,
      sources: sources ?? this.sources,
      actors: actors ?? this.actors,
      images: images ?? this.images,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Movie &&
          runtimeType == other.runtimeType &&
          movieId == other.movieId;

  @override
  int get hashCode => movieId.hashCode;

  String get formattedDuration {
    if (durationSeconds == null) return '';
    final duration = Duration(seconds: durationSeconds!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  bool get isSeries => movieType.toLowerCase() == 'series' || (totalSeasons != null && totalSeasons! > 0);
  
  String get mainImageUrl => primaryImageUrl ?? (images?.isNotEmpty == true ? images!.first.imageUrl : image);
  
  List<String> get genreNames => tags?.map((tag) => tag.tagName).toList() ?? [];
  
  String get formattedReleaseDate {
    if (releaseDate == null) return '';
    try {
      final date = DateTime.parse(releaseDate!);
      return '${date.year}';
    } catch (e) {
      return releaseDate ?? '';
    }
  }
  
  MovieSource? get primarySource => sources?.where((s) => s.isActive).firstOrNull;
  
  bool get requiresVip => sources?.any((s) => s.isVipOnly) == true;
}

@JsonSerializable()
class MovieRegion {
  @JsonKey(name: 'regionID')
  final int regionId;
  final String regionName;

  const MovieRegion({
    required this.regionId,
    required this.regionName,
  });

  factory MovieRegion.fromJson(Map<String, dynamic> json) => _$MovieRegionFromJson(json);
  Map<String, dynamic> toJson() => _$MovieRegionToJson(this);
}

@JsonSerializable()
class MovieTag {
  @JsonKey(name: 'tagID')
  final int tagId;
  final String tagName;
  final String? tagDescription;

  const MovieTag({
    required this.tagId,
    required this.tagName,
    this.tagDescription,
  });

  factory MovieTag.fromJson(Map<String, dynamic> json) => _$MovieTagFromJson(json);
  Map<String, dynamic> toJson() => _$MovieTagToJson(this);
}

@JsonSerializable()
class MovieSource {
  @JsonKey(name: 'movieSourceID')
  final int movieSourceId;
  @JsonKey(name: 'movieID')
  final int movieId;
  final String sourceName;
  final String sourceType;
  final String sourceUrl;
  final String? quality;
  final String? language;
  final bool isVipOnly;
  final bool isActive;

  const MovieSource({
    required this.movieSourceId,
    required this.movieId,
    required this.sourceName,
    required this.sourceType,
    required this.sourceUrl,
    this.quality,
    this.language,
    required this.isVipOnly,
    required this.isActive,
  });

  factory MovieSource.fromJson(Map<String, dynamic> json) => _$MovieSourceFromJson(json);
  Map<String, dynamic> toJson() => _$MovieSourceToJson(this);
}

@JsonSerializable()
class MovieActor {
  @JsonKey(name: 'personID')
  final int personId;
  final String fullName;
  final String? avatar;
  final String role;
  final String? characterName;
  final int? creditOrder;

  const MovieActor({
    required this.personId,
    required this.fullName,
    this.avatar,
    required this.role,
    this.characterName,
    this.creditOrder,
  });

  factory MovieActor.fromJson(Map<String, dynamic> json) => _$MovieActorFromJson(json);
  Map<String, dynamic> toJson() => _$MovieActorToJson(this);
}

@JsonSerializable()
class MovieImage {
  @JsonKey(name: 'movieImageID')
  final int movieImageId;
  final String imageUrl;

  const MovieImage({
    required this.movieImageId,
    required this.imageUrl,
  });

  factory MovieImage.fromJson(Map<String, dynamic> json) => _$MovieImageFromJson(json);
  Map<String, dynamic> toJson() => _$MovieImageToJson(this);
}