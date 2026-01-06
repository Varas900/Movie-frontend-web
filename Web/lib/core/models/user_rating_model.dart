class UserRating {
  final int userRatingId;
  final int userId;
  final int movieId;
  final int stars;
  final String? createdAt;
  final String? updatedAt;

  const UserRating({
    required this.userRatingId,
    required this.userId,
    required this.movieId,
    required this.stars,
    this.createdAt,
    this.updatedAt,
  });

  factory UserRating.fromJson(Map<String, dynamic> json) {
    final userRatingId = (json['userRatingID'] as num?)?.toInt() ??
        (json['userRatingId'] as num?)?.toInt() ??
        0;
    final userId = (json['userID'] as num?)?.toInt() ??
        (json['userId'] as num?)?.toInt() ??
        0;
    final movieId = (json['movieID'] as num?)?.toInt() ??
        (json['movieId'] as num?)?.toInt() ??
        0;
    final stars = (json['stars'] as num?)?.toInt() ??
        (json['rating'] as num?)?.toInt() ??
        (json['ratingValue'] as num?)?.toInt() ??
        0;

    return UserRating(
      userRatingId: userRatingId,
      userId: userId,
      movieId: movieId,
      stars: stars,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}
