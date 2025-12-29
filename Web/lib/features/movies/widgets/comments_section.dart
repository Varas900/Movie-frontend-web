import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/comment_model.dart';
import '../providers/comments_provider.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final canPost = ref.read(canPostCommentProvider);
    final userId = ref.read(currentUserIdProvider);
    final text = _controller.text.trim();

    if (!canPost || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    final repo = ref.read(commentsRepositoryProvider);
    final ok = await repo.createComment(
      movieId: widget.movieId,
      userId: userId,
      content: text,
      parentId: _replyingTo,
    );
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
                ...parents.map((c) => _buildCommentItem(c, replies[c.commentID] ?? const [])),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildComposer() {
    final canPost = ref.watch(canPostCommentProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(child: Icon(Icons.person)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: canPost ? 'Write a comment...' : 'Sign in to comment',
                  border: const OutlineInputBorder(),
                ),
                enabled: canPost && !_isPosting,
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

  Widget _buildCommentItem(Comment c, List<Comment> replies) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Text((c.userName?.isNotEmpty == true ? c.userName![0] : 'U').toUpperCase())),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.userName ?? 'User', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: 8),
                        Text(_formatDate(c.createdAt), style: Theme.of(context).textTheme.bodySmall),
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
                    if (replies.isNotEmpty) _buildRepliesList(replies),
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
      final canPost = ref.read(canPostCommentProvider);
      final userId = ref.read(currentUserIdProvider);
      final text = replyController.text.trim();
      if (!canPost || userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to reply')));
        return;
      }
      if (text.isEmpty) return;
      setState(() => _isPosting = true);
      final repo = ref.read(commentsRepositoryProvider);
      final ok = await repo.createComment(movieId: widget.movieId, userId: userId, content: text, parentId: parentId);
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

  Widget _buildRepliesList(List<Comment> replies) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 24),
      child: Column(
        children: replies.map((r) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 14, child: Text((r.userName?.isNotEmpty == true ? r.userName![0] : 'U').toUpperCase(), style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.userName ?? 'User', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: 8),
                        Text(_formatDate(r.createdAt), style: Theme.of(context).textTheme.bodySmall),
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

  class GroupedComments {
    final List<Comment> parents;
    final Map<int, List<Comment>> repliesByParent;
    GroupedComments(this.parents, this.repliesByParent);
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
