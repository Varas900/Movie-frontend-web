import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/review_model.dart';
import '../providers/reviews_provider.dart';

class ReviewsSection extends ConsumerWidget {
  final int movieId;

  const ReviewsSection({
    super.key,
    required this.movieId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(movieReviewsProvider(movieId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reviews',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                _showWriteReview(context, ref);
              },
              child: const Text('Write Review'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        reviewsAsync.when(
          loading: () => _buildLoadingReviews(),
          error: (error, stack) => _buildErrorWidget(context, ref),
          data: (reviews) => _buildReviewsList(context, reviews),
        ),
      ],
    );
  }

  Widget _buildLoadingReviews() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref) {
    return Container(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load reviews',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.refresh(movieReviewsProvider(movieId));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList(BuildContext context, List<Review> reviews) {
    if (reviews.isEmpty) {
      return Container(
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rate_review_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No reviews yet',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _showWriteReview(context, ConsumerRef);
                },
                child: const Text('Be the first to review'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Reviews Summary
        _buildReviewsSummary(context, reviews),
        
        const SizedBox(height: 16),
        
        // Reviews List
        ...reviews.take(3).map((review) => _buildReviewCard(context, review)),
        
        if (reviews.length > 3) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                _showAllReviews(context, reviews);
              },
              child: Text('View all ${reviews.length} reviews'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewsSummary(BuildContext context, List<Review> reviews) {
    final averageRating = reviews.fold<double>(0.0, (sum, review) => sum + review.rating) / reviews.length;
    final ratingCounts = <int, int>{};
    
    for (final review in reviews) {
      ratingCounts[review.rating] = (ratingCounts[review.rating] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Average Rating
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < averageRating.round() ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          
          const SizedBox(width: 24),
          
          // Rating Breakdown
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final rating = 5 - index;
                final count = ratingCounts[rating] ?? 0;
                final percentage = count / reviews.length;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$rating',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.star,
                        size: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$count',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer Info
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  review.userDisplayName.isNotEmpty 
                      ? review.userDisplayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userDisplayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < review.rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          _formatReviewDate(review.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Review Text
          Text(
            review.comment,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Helpful Actions
          if (review.helpfulCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${review.helpfulCount} helpful',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatReviewDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showAllReviews(BuildContext context, List<Review> reviews) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'All Reviews (${reviews.length})',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Reviews List
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      return _buildReviewCard(context, reviews[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWriteReview(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WriteReviewSheet(
        movieId: movieId,
        onSubmitted: () {
          ref.refresh(movieReviewsProvider(movieId));
        },
      ),
    );
  }
}

class WriteReviewSheet extends StatefulWidget {
  final int movieId;
  final VoidCallback onSubmitted;

  const WriteReviewSheet({
    super.key,
    required this.movieId,
    required this.onSubmitted,
  });

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Header
              Text(
                'Write a Review',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Rating
              Text(
                'Rating',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 16),
              
              // Comment
              Text(
                'Review',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _commentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Share your thoughts about this movie...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty == true) {
                    return 'Please enter your review';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting || _rating == 0 ? null : _submitReview,
                      child: _isSubmitting 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Submit review logic here
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      if (mounted) {
        widget.onSubmitted();
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}