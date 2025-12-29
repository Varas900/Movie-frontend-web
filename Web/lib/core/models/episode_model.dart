import 'package:json_annotation/json_annotation.dart';

part 'episode_model.g.dart';

@JsonSerializable()
class Episode {
  @JsonKey(name: 'episodeID')
  final int episodeId;
  
  @JsonKey(name: 'movieID')
  final int movieId;
  
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String? synopsis;
  final String? description;
  final int? durationSeconds;
  final String? releaseDate;
  final String? image;
  final String? videoUrl;
  final bool isVipOnly;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final List<EpisodeSource>? sources;
  final int? seriesId;

  const Episode({
    required this.episodeId,
    required this.movieId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    this.synopsis,
    this.description,
    this.durationSeconds,
    this.releaseDate,
    this.image,
    this.videoUrl,
    required this.isVipOnly,
    this.seriesId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.sources,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => _$EpisodeFromJson(json);
  Map<String, dynamic> toJson() => _$EpisodeToJson(this);

  Episode copyWith({
    int? episodeId,
    int? movieId,
    int? seasonNumber,
    int? episodeNumber,
    String? title,
    String? synopsis,
    String? description,
    int? durationSeconds,
    String? releaseDate,
    String? image,
    String? videoUrl,
    bool? isVipOnly,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    List<EpisodeSource>? sources,
  }) {
    return Episode(
      episodeId: episodeId ?? this.episodeId,
      movieId: movieId ?? this.movieId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      description: description ?? this.description,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      releaseDate: releaseDate ?? this.releaseDate,
      image: image ?? this.image,
      videoUrl: videoUrl ?? this.videoUrl,
      isVipOnly: isVipOnly ?? this.isVipOnly,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sources: sources ?? this.sources,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Episode &&
          runtimeType == other.runtimeType &&
          episodeId == other.episodeId;

  @override
  int get hashCode => episodeId.hashCode;

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

  String get episodeLabel => 'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
  
  String get fullTitle => '$episodeLabel: $title';
  
  EpisodeSource? get primarySource => sources?.where((s) => s.isActive).firstOrNull;
  
  String? get playbackUrl => primarySource?.sourceUrl ?? videoUrl;
}

@JsonSerializable()
class EpisodeSource {
  @JsonKey(name: 'episodeSourceID')
  final int episodeSourceId;
  
  @JsonKey(name: 'episodeID')
  final int episodeId;
  
  final String sourceName;
  final String sourceType;
  final String sourceUrl;
  final String? quality;
  final String? language;
  final bool isVipOnly;
  final bool isActive;

  const EpisodeSource({
    required this.episodeSourceId,
    required this.episodeId,
    required this.sourceName,
    required this.sourceType,
    required this.sourceUrl,
    this.quality,
    this.language,
    required this.isVipOnly,
    required this.isActive,
  });

  factory EpisodeSource.fromJson(Map<String, dynamic> json) => _$EpisodeSourceFromJson(json);
  Map<String, dynamic> toJson() => _$EpisodeSourceToJson(this);
}

@JsonSerializable()
class Advertisement {
  @JsonKey(name: 'adID')
  final int adId;
  
  final String title;
  final String? description;
  final String adType;
  final String contentUrl;
  final String? imageUrl;
  final int durationSeconds;
  final String? targetUrl;
  final bool isActive;
  final String? placement;
  final int priority;
  final String createdAt;
  final String updatedAt;

  const Advertisement({
    required this.adId,
    required this.title,
    this.description,
    required this.adType,
    required this.contentUrl,
    this.imageUrl,
    required this.durationSeconds,
    this.targetUrl,
    required this.isActive,
    this.placement,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) => _$AdvertisementFromJson(json);
  Map<String, dynamic> toJson() => _$AdvertisementToJson(this);

  String get formattedDuration {
    final duration = Duration(seconds: durationSeconds);
    return '${duration.inSeconds}s';
  }
  
  bool get isVideoAd => adType.toLowerCase() == 'video';
  bool get isBannerAd => adType.toLowerCase() == 'banner';
}