class SavedMovie {
  final int savedMovieId;
  final int movieId;
  final int userId;
  final DateTime? createdAt;

  const SavedMovie({
    required this.savedMovieId,
    required this.movieId,
    required this.userId,
    required this.createdAt,
  });

  factory SavedMovie.fromJson(Map<String, dynamic> json) {
    final savedId = (json['savedMovieID'] as num?)?.toInt() ??
        (json['savedMovieId'] as num?)?.toInt() ??
        (json['id'] as num?)?.toInt() ??
        0;
    final movieId = (json['movieID'] as num?)?.toInt() ??
        (json['movieId'] as num?)?.toInt() ??
        0;
    final userId = (json['userID'] as num?)?.toInt() ??
        (json['userId'] as num?)?.toInt() ??
        0;
    final createdAtRaw = json['createdAt'] ?? json['CreatedAt'] ?? json['created_at'];
    final createdAt = DateTime.tryParse(createdAtRaw?.toString() ?? '');

    return SavedMovie(
      savedMovieId: savedId,
      movieId: movieId,
      userId: userId,
      createdAt: createdAt,
    );
  }
}
