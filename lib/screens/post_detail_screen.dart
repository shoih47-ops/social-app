import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_app/screens/image_view_screen.dart';
import 'package:social_app/utils/time_ago.dart';
import 'package:social_app/widgets/comment_tile.dart';
// comment_with_replies is no longer used here
import 'package:social_app/widgets/reply_tile.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';

import '../services/notification_service.dart';
import '../services/post_service.dart';

import '../widgets/like_button.dart';
import '../widgets/comment_button.dart';

import '../models/post.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController commentController = TextEditingController();
  final Map<String, bool> _showReplies = {};
  Timer? _timeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timeRefreshTimer?.cancel();
    commentController.dispose();
    super.dispose();
  }

  Widget _buildMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF6D28D9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMoodCategoryChips(Post post) {
    final chips = <Widget>[
      if (post.mood.trim().isNotEmpty) _buildMetaChip(post.mood.trim()),
      if (post.category.trim().isNotEmpty) _buildMetaChip(post.category.trim()),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 3),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Future<void> addComment(Map<String, dynamic> data) async {
    if (commentController.text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final userData = userDoc.data() as Map<String, dynamic>;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
          "userId": user.uid,
          "username": userData['username'],
          "photoUrl": userData['photoUrl'],
          "text": commentController.text,
          "createdAt": FieldValue.serverTimestamp(),
          "likes": [],
        });

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({'commentCount': FieldValue.increment(1)});

    final username = userDoc.data()?['username'] ?? 'Someone';

    await sendNotification(
      toUserId: data['userId'],
      type: "comment",
      fromUserId: user.uid,
      fromUsername: username,
      postId: widget.postId,
    );

    commentController.clear();

    setState(() {});
  }

  void sendReply(
    String commentId,
    String commentOwnerId,
    String username,
    String text,
  ) async {
    if (!text.startsWith('@$username')) {
      text = '@$username $text';
    }

    final user = FirebaseAuth.instance.currentUser;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
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
            'isRead': false,
            'postId': widget.postId,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
          });
    }
  }

  void showReplyDialog(
    String commentId,
    String commentOwnerId,
    String username,
  ) {
    final mentionText = '@$username ';
    final controller = TextEditingController.fromValue(
      TextEditingValue(
        text: mentionText,
        selection: TextSelection.collapsed(offset: mentionText.length),
      ),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reply"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Write a reply..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cencel"),
            ),

            TextButton(
              onPressed: () {
                sendReply(commentId, commentOwnerId, username, controller.text);
                Navigator.pop(context);
              },
              child: const Text("Send"),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final post = Post(
            id: widget.postId,
            text: data['text'] ?? '',
            imageUrl: data['imageUrl'] ?? '',
            videoUrl: data['videoUrl'] ?? '',
            type: data['type'] ?? 'image',
            likedBy: List<String>.from(data['likes'] ?? []),
            comments: [],
            createdAt: TimeAgoHelper.fromFirestore(data['createdAt']),
            userId: data['userId'] ?? '',
            content: data['content'] ?? '',
            username: data['username'] ?? '',
            userPhoto: data['userPhoto'] ?? '',
            mood: data['mood'] ?? '',
            category: data['category'] ?? '',
          );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(post.userId)
                              .snapshots(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData ||
                                userSnapshot.data?.data() == null) {
                              return const SizedBox();
                            }

                            final userData =
                                userSnapshot.data?.data()
                                    as Map<String, dynamic>;

                            final currentUid =
                                FirebaseAuth.instance.currentUser!.uid;

                            final isOwner = post.userId == currentUid;

                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (isOwner) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ProfileScreen(userId: currentUid),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserProfileScreen(
                                            userId: post.userId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: const Color(
                                          0xfff3e8ff,
                                        ),
                                        backgroundImage:
                                            userData['photoUrl'] != null &&
                                                userData['photoUrl']
                                                    .toString()
                                                    .isNotEmpty
                                            ? NetworkImage(userData['photoUrl'])
                                            : null,
                                        child:
                                            userData['photoUrl'] == null ||
                                                userData['photoUrl']
                                                    .toString()
                                                    .isEmpty
                                            ? const Icon(
                                                Icons.person,
                                                color: Color(0xff8b5cf6),
                                                size: 20,
                                              )
                                            : null,
                                      ),

                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userData['username'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 2),

                                          _buildMoodCategoryChips(post),

                                          Text(
                                            TimeAgoHelper.format(
                                              post.createdAt,
                                              display: TimeAgoDisplay.detail,
                                            ),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                if (isOwner)
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Post'),
                                            content: const Text(
                                              'Are you sure you want to delete this post?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          print('DELETE ID: ${widget.postId}');
                                          if (mounted) Navigator.pop(context);
                                          await PostService.deletePost(
                                            widget.postId,
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete Post'),
                                      ),
                                    ],
                                  ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        if ((data['text'] ?? '').isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 32),
                            child: Text(
                              data['text'] ?? '',
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],

                        if ((data['imageUrl'] ?? '') != '')
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 500,
                                minHeight: 180,
                              ),
                              child: InteractiveViewer(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ImageViewScreen(
                                          imageUrl: data['imageUrl'],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    data['imageUrl'],
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 14),

                        // Videos are viewed in fullscreen; don't embed here.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            LikeButton(post: post),

                            const SizedBox(width: 24),

                            CommentButton(
                              postId: widget.postId,
                              postOwnerId: data['userId'],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.postId)
                              .collection('comments')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text('Failed to load comments'),
                                ),
                              );
                            }

                            if (!snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final comments = snapshot.data!.docs;

                            if (comments.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(child: Text('No comments yet')),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                final data = comments[index].data();

                                final likes = List<String>.from(
                                  data['likes'] ?? [],
                                );

                                return StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(data['userId'])
                                      .snapshots(),
                                  builder: (context, userSnapshot) {
                                    if (!userSnapshot.hasData) {
                                      return const SizedBox();
                                    }

                                    final userData =
                                        userSnapshot.data!.data()
                                            as Map<String, dynamic>;

                                    final currentUserId =
                                        FirebaseAuth.instance.currentUser!.uid;

                                    final isliked = likes.contains(
                                      currentUserId,
                                    );

                                    final commentId = comments[index].id;
                                    final show =
                                        _showReplies[commentId] ?? false;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.03),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            child: CommentTile(
                                              photoUrl:
                                                  (userData['photoUrl'] != null)
                                                  ? userData['photoUrl']
                                                  : '',
                                              username:
                                                  (userData['username'] != null)
                                                  ? userData['username']
                                                  : 'Deleted User',
                                              text: data['text'] ?? '',
                                              userId: data['userId'] ?? '',
                                              time: TimeAgoHelper.format(
                                                TimeAgoHelper.fromFirestore(
                                                  data['createdAt'],
                                                ),
                                              ),
                                              onReply: () {
                                                showReplyDialog(
                                                  commentId,
                                                  data['userId'],
                                                  userData['username'] ?? '',
                                                );
                                              },
                                              isLiked: isliked,
                                              likeCount: likes.length,
                                              onLike: () async {
                                                final ref = FirebaseFirestore
                                                    .instance
                                                    .collection('posts')
                                                    .doc(widget.postId)
                                                    .collection('comments')
                                                    .doc(commentId);

                                                if (isliked) {
                                                  await ref.update({
                                                    'likes':
                                                        FieldValue.arrayRemove([
                                                          currentUserId,
                                                        ]),
                                                  });
                                                } else {
                                                  await ref.update({
                                                    'likes':
                                                        FieldValue.arrayUnion([
                                                          currentUserId,
                                                        ]),
                                                  });
                                                }
                                              },
                                              onDelete: () async {
                                                await FirebaseFirestore.instance
                                                    .collection('posts')
                                                    .doc(widget.postId)
                                                    .collection('comments')
                                                    .doc(commentId)
                                                    .delete();
                                              },
                                            ),
                                          ),

                                          const SizedBox(height: 4),

                                          StreamBuilder(
                                            stream: FirebaseFirestore.instance
                                                .collection('posts')
                                                .doc(widget.postId)
                                                .collection('comments')
                                                .doc(commentId)
                                                .collection('replies')
                                                .orderBy('createdAt')
                                                .snapshots(),
                                            builder: (context, replySnapshot) {
                                              if (!replySnapshot.hasData) {
                                                return const SizedBox();
                                              }

                                              final replies =
                                                  replySnapshot.data!.docs;

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (replies.isNotEmpty)
                                                    TextButton(
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        minimumSize: const Size(
                                                          0,
                                                          0,
                                                        ),
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        alignment: Alignment
                                                            .centerLeft,
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          _showReplies[commentId] =
                                                              !(_showReplies[commentId] ??
                                                                  false);
                                                        });
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        child: Text(
                                                          show
                                                              ? 'Hide replies'
                                                              : 'View replies (${replies.length})',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey
                                                                .shade500,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ),
                                                    ),

                                                  if (show)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            left: 56,
                                                          ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Container(
                                                            width: 3,
                                                            height: 48,
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        2,
                                                                      ),
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical: 6,
                                                                    horizontal:
                                                                        0,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .grey
                                                                    .shade50,
                                                                borderRadius: const BorderRadius.only(
                                                                  topRight:
                                                                      Radius.circular(
                                                                        8,
                                                                      ),
                                                                  bottomRight:
                                                                      Radius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                              ),
                                                              child: Column(
                                                                children: replies.map((
                                                                  reply,
                                                                ) {
                                                                  final replyData =
                                                                      reply
                                                                          .data();
                                                                  return Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          bottom:
                                                                              4,
                                                                        ),
                                                                    child: ReplyTile(
                                                                      replyData:
                                                                          replyData,
                                                                      onDelete: () async {
                                                                        await FirebaseFirestore
                                                                            .instance
                                                                            .collection(
                                                                              'posts',
                                                                            )
                                                                            .doc(
                                                                              widget.postId,
                                                                            )
                                                                            .collection(
                                                                              'comments',
                                                                            )
                                                                            .doc(
                                                                              commentId,
                                                                            )
                                                                            .collection(
                                                                              'replies',
                                                                            )
                                                                            .doc(
                                                                              reply.id,
                                                                            )
                                                                            .delete();
                                                                      },
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentController,
                                  decoration: InputDecoration(
                                    hintText: 'Write a comment...',
                                    filled: true,
                                    fillColor: Colors.grey.shade200,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              GestureDetector(
                                onTap: () => addComment(data),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
