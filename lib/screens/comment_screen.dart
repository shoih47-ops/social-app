import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_app/widgets/comment_with_replies.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/notification_service.dart';
import '../widgets/comment_tile.dart';
import '../widgets/reply_tile.dart';

class CommentScreen extends StatefulWidget {
  final String postId;
  final String postOwnerId;

  const CommentScreen({
    super.key,
    required this.postId,
    required this.postOwnerId,
  });

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final commentController = TextEditingController();

  Future<void> addComment() async {
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
      toUserId: widget.postOwnerId,
      type: "comment",
      fromUserId: user.uid,
      fromUsername: username,
      postId: widget.postId,
    );

    commentController.clear();

    setState(() {});
  }

  void toggleLike(String commentId, List likes) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final ref = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    if (likes.contains(uid)) {
      likes.remove(uid);
    } else {
      likes.add(uid);
    }

    await ref.update({'likes': likes});
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
          title: Text("Reply"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Write a reply..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                sendReply(commentId, commentOwnerId, username, controller.text);
                Navigator.pop(context);
              },
              child: Text("Send"),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text("Comments")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No comments yet"));
                }

                final comments = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];

                    final data = comments[index].data() as Map<String, dynamic>;

                    final userId = data['userId'];

                    final likes = (data['likes'] is List) ? data['likes'] : [];
                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    final isLiked = likes.contains(uid);

                    return FutureBuilder(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .get(),

                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox();
                        }

                        final user =
                            snapshot.data!.data() as Map<String, dynamic>;

                        return CommentWithReplies(
                          commentTile: CommentTile(
                            photoUrl: user['photoUrl'],

                            username: user['username'] ?? 'Unknown',

                            text: data['text'] ?? '',

                            userId: data['userId'],

                            time: timeago.format(
                              (data['createdAt'] as Timestamp).toDate(),
                            ),

                            onReply: () {
                              showReplyDialog(
                                comment.id,
                                data['userId'],
                                user['username'] ?? '',
                              );
                            },

                            onLike: () {
                              toggleLike(comment.id, likes);
                            },

                            onDelete: () async {
                              await FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(widget.postId)
                                  .collection('comments')
                                  .doc(comment.id)
                                  .delete();
                            },

                            isLiked: isLiked,
                            likeCount: likes.length,
                          ),

                          repliesWidget: StreamBuilder(
                            stream: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(widget.postId)
                                .collection('comments')
                                .doc(comment.id)
                                .collection('replies')
                                .orderBy('createdAt')
                                .snapshots(),

                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox();
                              }

                              final replies = snapshot.data!.docs;

                              return Column(
                                children: replies.map((reply) {
                                  final replyData = reply.data();

                                  return ReplyTile(
                                    replyData: replyData,

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
                                  );
                                }).toList(),
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

          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: addComment,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
