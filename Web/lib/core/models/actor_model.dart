import 'package:json_annotation/json_annotation.dart';

part 'actor_model.g.dart';

@JsonSerializable()
class Actor {
  final int actorId;
  final String name;
  final String? image;
  final String? character;
  final String? biography;
  final DateTime? birthDate;
  final String? birthPlace;
  final List<String>? knownFor;
  final double? popularity;

  Actor({
    required this.actorId,
    required this.name,
    this.image,
    this.character,
    this.biography,
    this.birthDate,
    this.birthPlace,
    this.knownFor,
    this.popularity,
  });

  factory Actor.fromJson(Map<String, dynamic> json) => _$ActorFromJson(json);
  Map<String, dynamic> toJson() => _$ActorToJson(this);

  Actor copyWith({
    int? actorId,
    String? name,
    String? image,
    String? character,
    String? biography,
    DateTime? birthDate,
    String? birthPlace,
    List<String>? knownFor,
    double? popularity,
  }) {
    return Actor(
      actorId: actorId ?? this.actorId,
      name: name ?? this.name,
      image: image ?? this.image,
      character: character ?? this.character,
      biography: biography ?? this.biography,
      birthDate: birthDate ?? this.birthDate,
      birthPlace: birthPlace ?? this.birthPlace,
      knownFor: knownFor ?? this.knownFor,
      popularity: popularity ?? this.popularity,
    );
  }
}