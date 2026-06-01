import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_app/services/notification_service.dart';
import '../models/post.dart';

class LikeButton extends StatefulWidget {
  final Post post;
  final Color? iconColor; // optional override for icon color when not liked
  final Color? textColor; // optional override for text color

  const LikeButton({
    super.key,
    required this.post,
    this.iconColor,
    this.textColor,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return SizedBox();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List likedBy = data['likes'] ?? [];

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return SizedBox();
        bool isLiked = likedBy.contains(user.uid);

        return Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 22,
                color: isLiked
                    ? Colors.red
                    : (widget.iconColor ?? Colors.black),
              ),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser!;

                final postRef = FirebaseFirestore.instance
                    .collection("posts")
                    .doc(widget.post.id);

                if (isLiked) {
                  await postRef.update({
                    "likes": FieldValue.arrayRemove([user.uid]),
                  });
                } else {
                  await postRef.update({
                    "likes": FieldValue.arrayUnion([user.uid]),
                  });

                  // 🔔 send notification
                  if (!isLiked && widget.post.userId != user.uid) {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();

                    final username = userDoc.data()?['username'] ?? 'Someone';

                    await sendNotification(
                      toUserId: widget.post.userId,
                      type: "like",
                      fromUserId: user.uid,
                      fromUsername: username,
                      postId: widget.post.id,
                    );
                  }
                }
              },
            ),
            Text(
              likedBy.length.toString(),
              style: TextStyle(
                fontSize: 14,
                color: widget.textColor ?? Colors.black,
              ),
            ),
          ],
        );
      },
    );
  }
}
