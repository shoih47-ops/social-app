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
  final String postOwnerId;
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
    required this.postOwnerId,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF8B5CF6);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canDelete = currentUserId != null &&
        (userId == currentUserId || postOwnerId == currentUserId);
    final actionStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
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
              radius: 17,
              backgroundColor: const Color(0xFFF3E8FF),
              backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                  ? NetworkImage(photoUrl!)
                  : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 18, color: primaryColor)
                  : null,
            ),
          ),

          const SizedBox(width: 9),

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
                    style: const TextStyle(
                      color: Color(0xFF1F1F23),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  text,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Color(0xFF202124),
                    fontSize: 14,
                    height: 1.32,
                  ),
                ),

                const SizedBox(height: 6),

                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  runSpacing: 2,
                  children: [
                    Text(time, style: actionStyle),
                    Text('·', style: actionStyle),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onLike,
                      child: Text(
                        likeCount > 0 ? '❤️ $likeCount' : '♡ 0',
                        style: actionStyle.copyWith(
                          color: isLiked ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Text('·', style: actionStyle),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: actionStyle.copyWith(color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (canDelete)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.more_horiz,
                size: 18,
                color: Colors.grey.shade500,
              ),
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete Comment')),
              ],
            ),
        ],
      ),
    );
  }
}
