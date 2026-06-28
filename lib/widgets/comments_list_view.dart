import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/comment_service.dart';
import '../utils/time_ago.dart';
import 'comment_tile.dart';
import 'reply_dialog.dart';
import 'reply_tile.dart';

class CommentsListView extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets commentPadding;

  const CommentsListView({
    super.key,
    required this.postId,
    required this.postOwnerId,
    this.scrollController,
    this.physics,
    this.shrinkWrap = false,
    this.commentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  State<CommentsListView> createState() => _CommentsListViewState();
}

class _CommentsListViewState extends State<CommentsListView> {
  final CommentService _commentService = CommentService.instance;
  late final PostCommentsNotifier _postNotifier;
  ScrollController? _ownedScrollController;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _ownedScrollController!;

  @override
  void initState() {
    super.initState();
    _postNotifier = _commentService.notifierForPost(widget.postId);
    _postNotifier.addListener(_onCommentsChanged);

    if (widget.scrollController == null) {
      _ownedScrollController = ScrollController()..addListener(_onScroll);
    } else {
      widget.scrollController!.addListener(_onScroll);
    }

    _commentService.ensureCommentsLoaded(widget.postId);
  }

  @override
  void dispose() {
    _postNotifier.removeListener(_onCommentsChanged);
    if (_ownedScrollController != null) {
      _ownedScrollController!.removeListener(_onScroll);
      _ownedScrollController!.dispose();
    } else {
      widget.scrollController?.removeListener(_onScroll);
    }
    _commentService.stopWatchingPost(widget.postId);
    super.dispose();
  }

  void _onCommentsChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final controller = _effectiveScrollController;
    if (!controller.hasClients) return;
    if (controller.position.extentAfter > 240) return;
    if (!_commentService.hasMoreComments(widget.postId)) return;
    if (_commentService.isLoadingMore(widget.postId)) return;

    _commentService.loadMoreComments(widget.postId);
  }

  Future<void> _toggleLike(String commentId, List likes) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    if (likes.contains(uid)) {
      await ref.update({
        'likes': FieldValue.arrayRemove([uid]),
      });
    } else {
      await ref.update({
        'likes': FieldValue.arrayUnion([uid]),
      });
    }
  }

  void _showReplyDialog(
    String commentId,
    String commentOwnerId,
    String username,
  ) {
    showDialog(
      context: context,
      builder: (context) => ReplyDialog(
        username: username,
        onSend: (text) => _sendReply(commentId, commentOwnerId, text),
      ),
    );
  }

  Future<void> _sendReply(
    String commentId,
    String commentOwnerId,
    String text,
  ) async {
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data() as Map<String, dynamic>;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add({
      'text': text,
      'userId': user.uid,
      'username': userData['username'],
      'photoUrl': userData['photoUrl'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (commentOwnerId != user.uid) {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(commentOwnerId)
          .collection('items')
          .add({
        'toUserId': commentOwnerId,
        'fromUserId': user.uid,
        'type': 'reply',
        'fromUsername': userData['username'] ?? 'Someone',
        'isRead': false,
        'postId': widget.postId,
        'postType': '',
        'senderId': user.uid,
        'receiverId': commentOwnerId,
        'notificationType': 'reply',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = _commentService.commentsFor(widget.postId);
    final showInitialLoader =
        _commentService.isInitialLoading(widget.postId) && comments.isEmpty;

    if (showInitialLoader) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 24),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: Text('No comments yet')),
      );
    }

    final itemCount =
        comments.length + (_commentService.isLoadingMore(widget.postId) ? 1 : 0);

    return ListView.builder(
      controller: _effectiveScrollController,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= comments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final comment = comments[index];
        return _CommentListItem(
          key: ValueKey(comment.id),
          postId: widget.postId,
          postOwnerId: widget.postOwnerId,
          comment: comment,
          padding: widget.commentPadding,
          onReply: () => _showReplyDialog(
            comment.id,
            comment.userId,
            comment.username,
          ),
          onLike: () => _toggleLike(comment.id, List.from(comment.likes)),
          onDelete: () async {
            await FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .collection('comments')
                .doc(comment.id)
                .delete();
          },
        );
      },
    );
  }
}

class _CommentListItem extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final CommentEntry comment;
  final EdgeInsets padding;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _CommentListItem({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.comment,
    required this.padding,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  @override
  State<_CommentListItem> createState() => _CommentListItemState();
}

class _CommentListItemState extends State<_CommentListItem> {
  final CommentService _commentService = CommentService.instance;
  late final CommentRepliesNotifier _repliesNotifier;
  bool _showReplies = false;

  @override
  void initState() {
    super.initState();
    _repliesNotifier = _commentService.notifierForReplies(widget.comment.id);
    _repliesNotifier.addListener(_onRepliesChanged);
    _commentService.ensureRepliesLoaded(widget.postId, widget.comment.id);
  }

  @override
  void dispose() {
    _repliesNotifier.removeListener(_onRepliesChanged);
    _commentService.stopWatchingReplies(widget.comment.id);
    super.dispose();
  }

  void _onRepliesChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final likes = comment.likes;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isLiked = likes.contains(uid);
    final replies = _commentService.repliesFor(comment.id);

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: CommentTile(
              photoUrl: comment.photoUrl,
              username: comment.username,
              text: comment.text,
              userId: comment.userId,
              postOwnerId: widget.postOwnerId,
              time: TimeAgoHelper.format(
                TimeAgoHelper.fromFirestore(comment.createdAt),
              ),
              onReply: widget.onReply,
              onLike: widget.onLike,
              onDelete: widget.onDelete,
              isLiked: isLiked,
              likeCount: likes.length,
            ),
          ),
          const SizedBox(height: 4),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 2, bottom: 1),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () {
                  setState(() {
                    _showReplies = !_showReplies;
                  });
                },
                child: Text(
                  replies.length == 1 ? '1 Reply' : '${replies.length} Replies',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_showReplies)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 1),
              child: Column(
                children: replies
                    .map(
                      (reply) => ReplyTile(
                        key: ValueKey(reply.id),
                        replyData: reply.data,
                        repliedToUsername: comment.username,
                        postOwnerId: widget.postOwnerId,
                        onDelete: () async {
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.postId)
                              .collection('comments')
                              .doc(comment.id)
                              .collection('replies')
                              .doc(reply.id)
                              .delete();
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
