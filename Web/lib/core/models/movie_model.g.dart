// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Movie _$MovieFromJson(Map<String, dynamic> json) => Movie(
      movieId: (json['movieID'] as num).toInt(),
      slug: json['slug'] as String,
      title: json['title'] as String,
      originalTitle: json['originalTitle'] as String?,
      description: json['description'] as String?,
      movieType: json['movieType'] as String,
      image: json['image'] as String,
      status: json['status'] as String,
      releaseDate: json['releaseDate'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      totalSeasons: (json['totalSeasons'] as num?)?.toInt(),
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      rated: json['rated'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      regionId: (json['regionID'] as num).toInt(),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      region: json['region'] == null
          ? null
          : MovieRegion.fromJson(json['region'] as Map<String, dynamic>),
      tags: (json['tags'] as List<dynamic>?)
          ?.map((e) => MovieTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      sources: (json['sources'] as List<dynamic>?)
          ?.map((e) => MovieSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      actors: (json['actors'] as List<dynamic>?)
          ?.map((e) => MovieActor.fromJson(e as Map<String, dynamic>))
          .toList(),
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => MovieImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      imdbRating: (json['imdbRating'] as num?)?.toDouble(),
      plot: json['plot'] as String?,
      director: json['director'] as String?,
      writer: json['writer'] as String?,
      country: json['country'] as String?,
      language: json['language'] as String?,
      awards: json['awards'] as String?,
      boxOffice: json['boxOffice'] as String?,
      production: json['production'] as String?,
      primaryImageUrl: json['primaryImageUrl'] as String?,
    );

Map<String, dynamic> _$MovieToJson(Movie instance) => <String, dynamic>{
      'movieID': instance.movieId,
      'slug': instance.slug,
      'title': instance.title,
      'originalTitle': instance.originalTitle,
      'description': instance.description,
      'movieType': instance.movieType,
      'image': instance.image,
      'status': instance.status,
      'releaseDate': instance.releaseDate,
      'durationSeconds': instance.durationSeconds,
      'totalSeasons': instance.totalSeasons,
      'totalEpisodes': instance.totalEpisodes,
      'year': instance.year,
      'rated': instance.rated,
      'popularity': instance.popularity,
      'regionID': instance.regionId,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'region': instance.region,
      'tags': instance.tags,
      'sources': instance.sources,
      'actors': instance.actors,
      'images': instance.images,
      'imdbRating': instance.imdbRating,
      'plot': instance.plot,
      'director': instance.director,
      'writer': instance.writer,
      'country': instance.country,
      'language': instance.language,
      'awards': instance.awards,
      'boxOffice': instance.boxOffice,
      'production': instance.production,
      'primaryImageUrl': instance.primaryImageUrl,
    };

MovieRegion _$MovieRegionFromJson(Map<String, dynamic> json) => MovieRegion(
      regionId: (json['regionID'] as num).toInt(),
      regionName: json['regionName'] as String,
    );

Map<String, dynamic> _$MovieRegionToJson(MovieRegion instance) =>
    <String, dynamic>{
      'regionID': instance.regionId,
      'regionName': instance.regionName,
    };

MovieTag _$MovieTagFromJson(Map<String, dynamic> json) => MovieTag(
      tagId: (json['tagID'] as num).toInt(),
      tagName: json['tagName'] as String,
      tagDescription: json['tagDescription'] as String?,
    );

Map<String, dynamic> _$MovieTagToJson(MovieTag instance) => <String, dynamic>{
      'tagID': instance.tagId,
      'tagName': instance.tagName,
      'tagDescription': instance.tagDescription,
    };

MovieSource _$MovieSourceFromJson(Map<String, dynamic> json) => MovieSource(
      movieSourceId: (json['movieSourceID'] as num).toInt(),
      movieId: (json['movieID'] as num).toInt(),
      sourceName: json['sourceName'] as String,
      sourceType: json['sourceType'] as String,
      sourceUrl: json['sourceUrl'] as String,
      quality: json['quality'] as String?,
      language: json['language'] as String?,
      isVipOnly: json['isVipOnly'] as bool,
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$MovieSourceToJson(MovieSource instance) =>
    <String, dynamic>{
      'movieSourceID': instance.movieSourceId,
      'movieID': instance.movieId,
      'sourceName': instance.sourceName,
      'sourceType': instance.sourceType,
      'sourceUrl': instance.sourceUrl,
      'quality': instance.quality,
      'language': instance.language,
      'isVipOnly': instance.isVipOnly,
      'isActive': instance.isActive,
    };

MovieActor _$MovieActorFromJson(Map<String, dynamic> json) => MovieActor(
      personId: (json['personID'] as num).toInt(),
      fullName: json['fullName'] as String,
      avatar: json['avatar'] as String?,
      role: json['role'] as String,
      characterName: json['characterName'] as String?,
      creditOrder: (json['creditOrder'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MovieActorToJson(MovieActor instance) =>
    <String, dynamic>{
      'personID': instance.personId,
      'fullName': instance.fullName,
      'avatar': instance.avatar,
      'role': instance.role,
      'characterName': instance.characterName,
      'creditOrder': instance.creditOrder,
    };

MovieImage _$MovieImageFromJson(Map<String, dynamic> json) => MovieImage(
      movieImageId: (json['movieImageID'] as num).toInt(),
      imageUrl: json['imageUrl'] as String,
    );

Map<String, dynamic> _$MovieImageToJson(MovieImage instance) =>
    <String, dynamic>{
      'movieImageID': instance.movieImageId,
      'imageUrl': instance.imageUrl,
    };
