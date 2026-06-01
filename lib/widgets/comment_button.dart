import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/comment_screen.dart';

class CommentButton extends StatelessWidget {
  final String postId;
  final String postOwnerId;
  final Color? iconColor;
  final Color? textColor;

  const CommentButton({
    super.key,
    required this.postId,
    required this.postOwnerId,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;

        if (snapshot.hasData) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          count = data['commentCount'] ?? 0;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.comment_outlined,
                color: iconColor ?? Colors.black,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) {
                    return SizedBox(
                      height: MediaQuery.of(context).size.height * 0.9,
                      child: CommentScreen(
                        postId: postId,
                        postOwnerId: postOwnerId,
                      ),
                    );
                  },
                );
              },
            ),
            Text('$count', style: TextStyle(color: textColor ?? Colors.black)),
          ],
        );
      },
    );
  }
}
