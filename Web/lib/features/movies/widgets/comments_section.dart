import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/comment_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/authz_prompt.dart';
import '../../../core/utils/url_utils.dart';
import '../providers/comments_provider.dart';

class GroupedComments {
  final List<Comment> parents;
  final Map<int, List<Comment>> repliesByParent;
  GroupedComments(this.parents, this.repliesByParent);
}

class CommentsSection extends ConsumerStatefulWidget {
  final int movieId;

  const CommentsSection({super.key, required this.movieId});

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final TextEditingController _controller = TextEditingController();
  int? _replyingTo;
  bool _isPosting = false;

  Future<void> _editComment(Comment c) async {
    final ctrl = TextEditingController(text: c.content);
    final repo = ref.read(commentsRepositoryProvider);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit comment'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final text = result?.trim();
    if (text == null || text.isEmpty || text == c.content) return;

    try {
      final ok = await repo.updateComment(comment: c, content: text);
      if (ok) {
        ref.invalidate(commentsProvider(widget.movieId));
      }
    } catch (e) {
      final prompt = authzPromptFromError(e);
      if (prompt == AuthzPromptType.signIn) {
        if (!mounted) return;
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
        if (!mounted) return;
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.buyPlan,
          onPrimary: () => context.go('${AppRoutes.profile}?tab=subscription'),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update comment: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(Comment c) async {
    final repo = ref.read(commentsRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete comment'),
        content: const Text('Delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final ok = await repo.deleteComment(commentId: c.commentID);
      if (ok) {
        ref.invalidate(commentsProvider(widget.movieId));
      }
    } catch (e) {
      final prompt = authzPromptFromError(e);
      if (prompt == AuthzPromptType.signIn) {
        if (!mounted) return;
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
        if (!mounted) return;
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.buyPlan,
          onPrimary: () => context.go('${AppRoutes.profile}?tab=subscription'),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final userId = ref.read(currentUserIdProvider);
    final text = _controller.text.trim();

    if (userId == null) {
      await showAuthzPromptDialog(
        context,
        type: AuthzPromptType.signIn,
        onPrimary: () => context.go(AppRoutes.signin),
      );
      return;
    }
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    final repo = ref.read(commentsRepositoryProvider);
    bool ok = false;
    try {
      ok = await repo.createComment(
        movieId: widget.movieId,
        userId: userId,
        content: text,
        parentId: _replyingTo,
      );
    } catch (e) {
      final prompt = authzPromptFromError(e);
      if (prompt == AuthzPromptType.signIn) {
        if (!mounted) return;
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
        if (!mounted) return;
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.buyPlan,
          onPrimary: () => context.go('${AppRoutes.profile}?tab=subscription'),
        );
        return;
      }
      ok = false;
    }
    setState(() => _isPosting = false);

    if (ok) {
      _controller.clear();
      setState(() => _replyingTo = null);
      ref.invalidate(commentsProvider(widget.movieId));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post comment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.movieId));
    final commentersAsync = ref.watch(commenterProfilesByMovieProvider(widget.movieId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _buildComposer(),
        const SizedBox(height: 16),
        commentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text('Failed to load comments'),
          data: (comments) {
            if (comments.isEmpty) {
              return const Text('No comments yet');
            }
            final commenterMap = commentersAsync.value ?? const <int, CommenterProfile>{};
            final grouped = _groupComments(comments);
            final parents = grouped.parents;
            final replies = grouped.repliesByParent;
            return Column(
              children: [
                Row(
                  children: [
                    Text('${comments.length} comments', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 8),
                ...parents.map((c) =>
                    _buildCommentItem(c, replies[c.commentID] ?? const [], commenterMap)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildComposer() {
    final isAuthed = ref.watch(isAuthenticatedProvider);
    final me = ref.watch(currentUserProvider);
    final avatarUrl = resolveApiUrl(me?.avatar);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: isAuthed ? 'Write a comment...' : 'Sign in to comment',
                  border: const OutlineInputBorder(),
                ),
                enabled: !_isPosting,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _postComment,
                  child: _isPosting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Post Comment'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(
      Comment c, List<Comment> replies, Map<int, CommenterProfile> commenterMap) {
    final me = ref.watch(currentUserProvider);
    final meId = me?.userId;
    final isMe = meId != null && c.userID == meId;
    final other = commenterMap[c.userID];
    final displayName = isMe
        ? (me?.userName)
        : (other?.userName.isNotEmpty == true ? other!.userName : c.userName);
    final avatarUrl = isMe
        ? resolveApiUrl(me?.avatar)
        : resolveApiUrl(other?.avatar);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isNotEmpty
                    ? null
                    : Text(
                        ((displayName?.isNotEmpty == true ? displayName![0] : 'U')).toUpperCase(),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(displayName ?? 'User', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: 8),
                        Text(_formatDate(c.createdAt), style: Theme.of(context).textTheme.bodySmall),
                        const Spacer(),
                        if (isMe)
                          PopupMenuButton<String>(
                            tooltip: 'Comment actions',
                            onSelected: (v) async {
                              switch (v) {
                                case 'edit':
                                  await _editComment(c);
                                  break;
                                case 'delete':
                                  await _deleteComment(c);
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.content),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _replyingTo = c.commentID);
                          },
                          child: const Text('Reply'),
                        ),
                      ],
                    ),
                    if (_replyingTo == c.commentID) _buildReplyComposer(parentId: c.commentID),
                    if (replies.isNotEmpty)
                      _buildRepliesList(replies, commenterMap),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyComposer({required int parentId}) {
    final replyController = TextEditingController();

    Future<void> submitReply() async {
      final userId = ref.read(currentUserIdProvider);
      final text = replyController.text.trim();
      if (userId == null) {
        await showAuthzPromptDialog(
          context,
          type: AuthzPromptType.signIn,
          onPrimary: () => context.go(AppRoutes.signin),
        );
        return;
      }
      if (text.isEmpty) return;
      setState(() => _isPosting = true);
      final repo = ref.read(commentsRepositoryProvider);
      bool ok = false;
      try {
        ok = await repo.createComment(
          movieId: widget.movieId,
          userId: userId,
          content: text,
          parentId: parentId,
        );
      } catch (e) {
        final prompt = authzPromptFromError(e);
        if (prompt == AuthzPromptType.signIn) {
          if (!mounted) return;
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
          if (!mounted) return;
          await showAuthzPromptDialog(
            context,
            type: AuthzPromptType.buyPlan,
            onPrimary: () => context.go('${AppRoutes.profile}?tab=subscription'),
          );
          return;
        }
        ok = false;
      }
      setState(() => _isPosting = false);
      if (ok) {
        ref.invalidate(commentsProvider(widget.movieId));
        setState(() => _replyingTo = null);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reply')));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: replyController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _isPosting ? null : submitReply, child: const Text('Reply')),
        ],
      ),
    );
  }

  Widget _buildRepliesList(
      List<Comment> replies, Map<int, CommenterProfile> commenterMap) {
    final me = ref.watch(currentUserProvider);
    final meId = me?.userId;
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 24),
      child: Column(
        children: replies.map((r) {
          final isMe = meId != null && r.userID == meId;
          final other = commenterMap[r.userID];
          final displayName = isMe
              ? me?.userName
              : (other?.userName.isNotEmpty == true
                  ? other!.userName
                  : (r.userName ?? 'User'));
          final avatarUrl = isMe
              ? resolveApiUrl(me?.avatar)
              : resolveApiUrl(other?.avatar);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isNotEmpty
                    ? null
                    : Text(
                        ((displayName?.isNotEmpty == true
                                ? displayName![0]
                                : 'U'))
                            .toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(displayName ?? 'User',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: 8),
                        Text(_formatDate(r.createdAt), style: Theme.of(context).textTheme.bodySmall),
                        const Spacer(),
                        if (isMe)
                          PopupMenuButton<String>(
                            tooltip: 'Comment actions',
                            onSelected: (v) async {
                              switch (v) {
                                case 'edit':
                                  await _editComment(r);
                                  break;
                                case 'delete':
                                  await _deleteComment(r);
                                  break;
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r.content),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  GroupedComments _groupComments(List<Comment> all) {
    final parents = all.where((c) => c.parentID == null || c.parentID == 0).toList();
    final repliesList = all.where((c) => c.parentID != null && c.parentID != 0).toList();
    final Map<int, List<Comment>> repliesByParent = {};
    for (final r in repliesList) {
      final key = r.parentID!;
      repliesByParent.putIfAbsent(key, () => []);
      repliesByParent[key]!.add(r);
    }
    // sort parents and replies by createdAt desc
    parents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final entry in repliesByParent.entries) {
      entry.value.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // replies older-first under a parent
    }
    return GroupedComments(parents, repliesByParent);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
