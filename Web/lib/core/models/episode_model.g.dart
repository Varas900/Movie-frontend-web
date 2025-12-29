// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Episode _$EpisodeFromJson(Map<String, dynamic> json) => Episode(
      episodeId: (json['episodeID'] as num).toInt(),
      movieId: (json['movieID'] as num).toInt(),
      seasonNumber: (json['seasonNumber'] as num).toInt(),
      episodeNumber: (json['episodeNumber'] as num).toInt(),
      title: json['title'] as String,
      synopsis: json['synopsis'] as String?,
      description: json['description'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      releaseDate: json['releaseDate'] as String?,
      image: json['image'] as String?,
      videoUrl: json['videoUrl'] as String?,
      isVipOnly: json['isVipOnly'] as bool,
      seriesId: (json['seriesId'] as num?)?.toInt(),
      isActive: json['isActive'] as bool,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      sources: (json['sources'] as List<dynamic>?)
          ?.map((e) => EpisodeSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$EpisodeToJson(Episode instance) => <String, dynamic>{
      'episodeID': instance.episodeId,
      'movieID': instance.movieId,
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
      'title': instance.title,
      'synopsis': instance.synopsis,
      'description': instance.description,
      'durationSeconds': instance.durationSeconds,
      'releaseDate': instance.releaseDate,
      'image': instance.image,
      'videoUrl': instance.videoUrl,
      'isVipOnly': instance.isVipOnly,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'sources': instance.sources,
      'seriesId': instance.seriesId,
    };

EpisodeSource _$EpisodeSourceFromJson(Map<String, dynamic> json) =>
    EpisodeSource(
      episodeSourceId: (json['episodeSourceID'] as num).toInt(),
      episodeId: (json['episodeID'] as num).toInt(),
      sourceName: json['sourceName'] as String,
      sourceType: json['sourceType'] as String,
      sourceUrl: json['sourceUrl'] as String,
      quality: json['quality'] as String?,
      language: json['language'] as String?,
      isVipOnly: json['isVipOnly'] as bool,
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$EpisodeSourceToJson(EpisodeSource instance) =>
    <String, dynamic>{
      'episodeSourceID': instance.episodeSourceId,
      'episodeID': instance.episodeId,
      'sourceName': instance.sourceName,
      'sourceType': instance.sourceType,
      'sourceUrl': instance.sourceUrl,
      'quality': instance.quality,
      'language': instance.language,
      'isVipOnly': instance.isVipOnly,
      'isActive': instance.isActive,
    };

Advertisement _$AdvertisementFromJson(Map<String, dynamic> json) =>
    Advertisement(
      adId: (json['adID'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      adType: json['adType'] as String,
      contentUrl: json['contentUrl'] as String,
      imageUrl: json['imageUrl'] as String?,
      durationSeconds: (json['durationSeconds'] as num).toInt(),
      targetUrl: json['targetUrl'] as String?,
      isActive: json['isActive'] as bool,
      placement: json['placement'] as String?,
      priority: (json['priority'] as num).toInt(),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );

Map<String, dynamic> _$AdvertisementToJson(Advertisement instance) =>
    <String, dynamic>{
      'adID': instance.adId,
      'title': instance.title,
      'description': instance.description,
      'adType': instance.adType,
      'contentUrl': instance.contentUrl,
      'imageUrl': instance.imageUrl,
      'durationSeconds': instance.durationSeconds,
      'targetUrl': instance.targetUrl,
      'isActive': instance.isActive,
      'placement': instance.placement,
      'priority': instance.priority,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };
