import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/user_profile_screen.dart';
import '../screens/profile_screen.dart';

class CommentTile extends StatelessWidget {
  final String username;
  final String text;
  final String time;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final bool isLiked;
  final int likeCount;
  final String userId;
  final String? photoUrl;

  const CommentTile({
    super.key,
    required this.username,
    required this.text,
    required this.time,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
    required this.isLiked,
    required this.likeCount,
    required this.userId,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              final currentUser = FirebaseAuth.instance.currentUser;

              if (currentUser != null && currentUser.uid == userId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: currentUser.uid),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: userId),
                  ),
                );
              }
            },

            child: CircleAvatar(
              radius: 18,
              backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                  ? NetworkImage(photoUrl!)
                  : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? const Icon(Icons.person)
                  : null,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    final currentUser = FirebaseAuth.instance.currentUser;

                    if (currentUser != null && currentUser.uid == userId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(userId: currentUser.uid),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(userId: userId),
                        ),
                      );
                    }
                  },

                  child: Text(
                    username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 3),

                Text(text, softWrap: true, overflow: TextOverflow.visible),

                const SizedBox(height: 4),

                Text(
                  time,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),

                const SizedBox(height: 2),

                GestureDetector(
                  onTap: onReply,
                  child: const Text(
                    "Reply",
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          if (userId == FirebaseAuth.instance.currentUser!.uid)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete Comment')),
              ],
            ),

          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                    size: 22,
                  ),
                ),

                const SizedBox(height: 2),

                if (likeCount > 0)
                  Text(
                    '$likeCount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
