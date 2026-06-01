import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_app/screens/image_view_screen.dart';
import 'package:social_app/utils/time_ago.dart';
import 'package:social_app/widgets/comment_tile.dart';
import 'package:social_app/widgets/comment_with_replies.dart';
import 'package:social_app/widgets/reply_tile.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';

import '../services/notification_service.dart';

import '../widgets/like_button.dart';
import '../widgets/comment_button.dart';

import 'package:timeago/timeago.dart' as timeago;

import '../models/post.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController commentController = TextEditingController();

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
          "createdAt": Timestamp.now(),
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
          'createdAt': Timestamp.now(),
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
            'createdAt': Timestamp.now(),
          });
    }
  }

  void showReplyDialog(
    String commentId,
    String commentOwnerId,
    String username,
  ) {
    TextEditingController controller = TextEditingController(
      text: '@$username ',
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
    );
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
            createdAt: data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
            userId: data['userId'] ?? '',
            content: data['content'] ?? '',
            username: data['username'] ?? '',
            userPhoto: data['userPhoto'] ?? '',
          );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final currentUid =
                                FirebaseAuth.instance.currentUser!.uid;

                            if (post.userId == currentUid) {
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
                                  builder: (_) =>
                                      UserProfileScreen(userId: post.userId),
                                ),
                              );
                            }
                          },

                          child: StreamBuilder(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(post.userId)
                                .snapshots(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData ||
                                  userSnapshot.data!.data() == null) {
                                return const SizedBox();
                              }

                              final userData =
                                  userSnapshot.data!.data()
                                      as Map<String, dynamic>;

                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xfff3e8ff),
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

                                      Text(
                                        timeAgo(post.createdAt),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
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

                        Expanded(
                          child: StreamBuilder(
                            stream: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(widget.postId)
                                .collection('comments')
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox();
                              }

                              final comments = snapshot.data!.docs;

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
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

                                      final currentUserId = FirebaseAuth
                                          .instance
                                          .currentUser!
                                          .uid;

                                      final isliked = likes.contains(
                                        currentUserId,
                                      );

                                      return CommentWithReplies(
                                        commentTile: CommentTile(
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
                                          time: timeago.format(
                                            (data['createdAt'] as Timestamp)
                                                .toDate(),
                                          ),

                                          onReply: () {
                                            showReplyDialog(
                                              comments[index].id,
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
                                                .doc(comments[index].id);

                                            if (isliked) {
                                              await ref.update({
                                                'likes': FieldValue.arrayRemove(
                                                  [currentUserId],
                                                ),
                                              });
                                            } else {
                                              await ref.update({
                                                'likes': FieldValue.arrayUnion([
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
                                                .doc(comments[index].id)
                                                .delete();
                                          },
                                        ),

                                        repliesWidget: StreamBuilder(
                                          stream: FirebaseFirestore.instance
                                              .collection('posts')
                                              .doc(widget.postId)
                                              .collection('comments')
                                              .doc(comments[index].id)
                                              .collection('replies')
                                              .orderBy('createdAt')
                                              .snapshots(),
                                          builder: (context, replySnapshot) {
                                            if (!replySnapshot.hasData) {
                                              return const SizedBox();
                                            }

                                            final replies =
                                                replySnapshot.data!.docs;

                                            return ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: replies.length,
                                              itemBuilder: (context, replyIndex) {
                                                final replyData =
                                                    replies[replyIndex].data();

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 40,
                                                        top: 8,
                                                      ),
                                                  child: ReplyTile(
                                                    replyData: replyData,

                                                    onDelete: () async {
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('posts')
                                                          .doc(widget.postId)
                                                          .collection(
                                                            'comments',
                                                          )
                                                          .doc(
                                                            comments[index].id,
                                                          )
                                                          .collection('replies')
                                                          .doc(
                                                            replies[replyIndex]
                                                                .id,
                                                          )
                                                          .delete();
                                                    },
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
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
