// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Actor _$ActorFromJson(Map<String, dynamic> json) => Actor(
      actorId: (json['actorId'] as num).toInt(),
      name: json['name'] as String,
      image: json['image'] as String?,
      character: json['character'] as String?,
      biography: json['biography'] as String?,
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.parse(json['birthDate'] as String),
      birthPlace: json['birthPlace'] as String?,
      knownFor: (json['knownFor'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      popularity: (json['popularity'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ActorToJson(Actor instance) => <String, dynamic>{
      'actorId': instance.actorId,
      'name': instance.name,
      'image': instance.image,
      'character': instance.character,
      'biography': instance.biography,
      'birthDate': instance.birthDate?.toIso8601String(),
      'birthPlace': instance.birthPlace,
      'knownFor': instance.knownFor,
      'popularity': instance.popularity,
    };
