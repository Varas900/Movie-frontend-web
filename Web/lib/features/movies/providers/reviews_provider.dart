import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/review_model.dart';
import '../../../core/services/api_service.dart';

// Movie Reviews Provider
final movieReviewsProvider = FutureProvider.family<List<Review>, int>((ref, movieId) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getMovieReviews(movieId);
});

// User Reviews Provider
final userReviewsProvider = FutureProvider.family<List<Review>, int>((ref, userId) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getUserReviews(userId);
});

// Recent Reviews Provider
final recentReviewsProvider = FutureProvider<List<Review>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getRecentReviews();
});

// Submit Review Provider
final submitReviewProvider = FutureProvider.family<bool, ReviewSubmission>((ref, submission) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.submitReview(submission);
});

// Review Submission Data Class
class ReviewSubmission {
  final int movieId;
  final int rating;
  final String comment;

  const ReviewSubmission({
    required this.movieId,
    required this.rating,
    required this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'movieId': movieId,
      'rating': rating,
      'comment': comment,
    };
  }
}

// Like/Dislike Review Provider
final likeReviewProvider = FutureProvider.family<bool, int>((ref, reviewId) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.likeReview(reviewId);
});

// Report Review Provider
final reportReviewProvider = FutureProvider.family<bool, ReviewReport>((ref, report) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.reportReview(report);
});

// Review Report Data Class
class ReviewReport {
  final int reviewId;
  final String reason;
  final String? description;

  const ReviewReport({
    required this.reviewId,
    required this.reason,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'reviewId': reviewId,
      'reason': reason,
      if (description != null) 'description': description,
    };
  }
}