import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/authz_prompt.dart';
import '../../../core/providers/subscription_provider.dart';
import '../providers/user_rating_provider.dart';

class UserRatingSection extends ConsumerStatefulWidget {
  final int movieId;

  const UserRatingSection({super.key, required this.movieId});

  @override
  ConsumerState<UserRatingSection> createState() => _UserRatingSectionState();
}

class _UserRatingSectionState extends ConsumerState<UserRatingSection> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAuthed = ref.watch(isAuthenticatedProvider);

    final hasPlanAsync = ref.watch(hasActiveSubscriptionProvider);
    final myRatingAsync = ref.watch(myUserRatingProvider(widget.movieId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate this Movie',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          hasPlanAsync.when(
            loading: () => _buildBoxedStars(
              isAuthenticated: isAuthed,
              hasPlan: false,
              currentStarsAsync: myRatingAsync,
              hint: isAuthed ? 'Checking your plan...' : 'Sign in to rate this movie',
            ),
            error: (e, st) => _buildBoxedStars(
              isAuthenticated: isAuthed,
              hasPlan: false,
              currentStarsAsync: myRatingAsync,
              hint: isAuthed ? 'Buy a plan to rate this movie' : 'Sign in to rate this movie',
            ),
            data: (hasPlan) => _buildBoxedStars(
              isAuthenticated: isAuthed,
              hasPlan: hasPlan,
              currentStarsAsync: myRatingAsync,
              hint: !isAuthed
                  ? 'Sign in to rate this movie'
                  : hasPlan
                      ? 'Tap a star to rate this movie'
                      : 'Buy a plan to rate this movie',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxedStars({
    required bool isAuthenticated,
    required bool hasPlan,
    required AsyncValue currentStarsAsync,
    required String hint,
  }) {
    return currentStarsAsync.when(
      loading: () => _boxedStarsRow(
        isAuthenticated: isAuthenticated,
        hasPlan: hasPlan,
        currentStars: 0,
        hint: 'Loading your rating...',
      ),
      error: (e, st) => _boxedStarsRow(
        isAuthenticated: isAuthenticated,
        hasPlan: hasPlan,
        currentStars: 0,
        hint: hint,
      ),
      data: (myRating) => _boxedStarsRow(
        isAuthenticated: isAuthenticated,
        hasPlan: hasPlan,
        currentStars: (myRating?.stars ?? 0).clamp(0, 5),
        hint: hint,
        userRatingId: myRating?.userRatingId,
      ),
    );
  }

  Widget _boxedStarsRow({
    required bool isAuthenticated,
    required bool hasPlan,
    required int currentStars,
    required String hint,
    int? userRatingId,
  }) {
    final disabled = _isSubmitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final idx = i + 1;
            final selected = idx <= currentStars;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: disabled
                    ? null
                    : () async {
                        if (!isAuthenticated) {
                          await showAuthzPromptDialog(
                            context,
                            type: AuthzPromptType.signIn,
                            onPrimary: () => context.go(AppRoutes.signin),
                          );
                          return;
                        }
                        if (!hasPlan) {
                          await showAuthzPromptDialog(
                            context,
                            type: AuthzPromptType.buyPlan,
                            onPrimary: () => context.go('${AppRoutes.profile}?tab=subscription'),
                          );
                          return;
                        }
                        await _submitRating(idx, userRatingId: userRatingId);
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.6)),
                  ),
                  child: Icon(
                    selected ? Icons.star : Icons.star_border,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(selected ? 0.9 : 0.35),
                    size: 26,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          hint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
        ),
        if (_isSubmitting) ...[
          const SizedBox(height: 10),
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ],
    );
  }

  Future<void> _submitRating(int stars, {int? userRatingId}) async {
    if (stars <= 0) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.userId ?? 0;
      if (userId <= 0) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.signIn,
          onPrimary: () => context.go(AppRoutes.signin),
        );
        return;
      }
      final repo = ref.read(userRatingRepositoryProvider);

      UserRating? updated;
      try {
        updated = await repo.upsertRating(
          movieId: widget.movieId,
          userId: userId,
          stars: stars,
          userRatingId: userRatingId,
        );
      } catch (e) {
        final prompt = authzPromptFromError(e);
        if (!mounted) return;
        if (prompt == AuthzPromptType.signIn) {
          await showAuthzPromptDialog(
            context,
            type: AuthzPromptType.signIn,
            onPrimary: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.signin);
            },
          );
          return;
        }
        if (prompt == AuthzPromptType.buyPlan) {
          await showAuthzPromptDialog(
            context,
            type: AuthzPromptType.buyPlan,
            onPrimary: () => context.go('${AppRoutes.profile}?tab=subscription'),
          );
          return;
        }
        updated = null;
      }

      if (!mounted) return;

      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit rating')),
        );
      } else {
        ref.invalidate(myUserRatingProvider(widget.movieId));
        ref.invalidate(movieUserRatingsProvider(widget.movieId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
