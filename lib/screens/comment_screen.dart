import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../utils/time_ago.dart';
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
  final Map<String, bool> _showReplies = {};

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

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
          "createdAt": FieldValue.serverTimestamp(),
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
              child: const Text("Cancel"),
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
                    final data = comment.data() as Map<String, dynamic>;
                    final userId = data['userId'];

                    final likes = (data['likes'] is List) ? data['likes'] : [];
                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    final isLiked = likes.contains(uid);

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox();
                        final user =
                            userSnap.data!.data() as Map<String, dynamic>;

                        final show = _showReplies[comment.id] ?? false;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Comment card
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
                                  photoUrl: user['photoUrl'],
                                  username: user['username'] ?? 'Unknown',
                                  text: data['text'] ?? '',
                                  userId: data['userId'],
                                  time: TimeAgoHelper.format(
                                    TimeAgoHelper.fromFirestore(
                                      data['createdAt'],
                                    ),
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
                              ),

                              // Replies toggle & list
                              const SizedBox(height: 4),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('posts')
                                    .doc(widget.postId)
                                    .collection('comments')
                                    .doc(comment.id)
                                    .collection('replies')
                                    .orderBy('createdAt')
                                    .snapshots(),
                                builder: (context, snap) {
                                  if (!snap.hasData) return const SizedBox();
                                  final replies = snap.data!.docs;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (replies.isNotEmpty)
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            alignment: Alignment.centerLeft,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _showReplies[comment.id] =
                                                  !(_showReplies[comment.id] ??
                                                      false);
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            child: Text(
                                              show
                                                  ? 'Hide replies'
                                                  : 'View replies (${replies.length})',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),

                                      if (show)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 56,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Short connector line
                                              Container(
                                                width: 3,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade300,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 0,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius:
                                                        const BorderRadius.only(
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
                                                          reply.data()
                                                              as Map<
                                                                String,
                                                                dynamic
                                                              >;
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 4,
                                                            ),
                                                        child: ReplyTile(
                                                          replyData: replyData,
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
                                                                .doc(comment.id)
                                                                .collection(
                                                                  'replies',
                                                                )
                                                                .doc(reply.id)
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
          ),

          // Input bar fixed at bottom
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
