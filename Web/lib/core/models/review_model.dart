class Review {
  final int reviewId;
  final int movieId;
  final int userId;
  final String userDisplayName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int helpfulCount;
  final bool isVerifiedPurchase;

  Review({
    required this.reviewId,
    required this.movieId,
    required this.userId,
    required this.userDisplayName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    this.helpfulCount = 0,
    this.isVerifiedPurchase = false,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      reviewId: json['reviewId'] ?? json['id'] ?? 0,
      movieId: json['movieId'] ?? 0,
      userId: json['userId'] ?? 0,
      userDisplayName: json['userDisplayName'] ?? json['userName'] ?? 'Anonymous',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? json['review'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      helpfulCount: json['helpfulCount'] ?? 0,
      isVerifiedPurchase: json['isVerifiedPurchase'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewId': reviewId,
      'movieId': movieId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'helpfulCount': helpfulCount,
      'isVerifiedPurchase': isVerifiedPurchase,
    };
  }

  Review copyWith({
    int? reviewId,
    int? movieId,
    int? userId,
    String? userDisplayName,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? helpfulCount,
    bool? isVerifiedPurchase,
  }) {
    return Review(
      reviewId: reviewId ?? this.reviewId,
      movieId: movieId ?? this.movieId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Review &&
        other.reviewId == reviewId &&
        other.movieId == movieId &&
        other.userId == userId &&
        other.userDisplayName == userDisplayName &&
        other.rating == rating &&
        other.comment == comment &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.helpfulCount == helpfulCount &&
        other.isVerifiedPurchase == isVerifiedPurchase;
  }

  @override
  int get hashCode {
    return reviewId.hashCode ^
        movieId.hashCode ^
        userId.hashCode ^
        userDisplayName.hashCode ^
        rating.hashCode ^
        comment.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        helpfulCount.hashCode ^
        isVerifiedPurchase.hashCode;
  }

  @override
  String toString() {
    return 'Review(reviewId: $reviewId, movieId: $movieId, userId: $userId, userDisplayName: $userDisplayName, rating: $rating, comment: $comment, createdAt: $createdAt, updatedAt: $updatedAt, helpfulCount: $helpfulCount, isVerifiedPurchase: $isVerifiedPurchase)';
  }
}