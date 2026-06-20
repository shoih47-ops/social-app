import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_app/screens/user_profile_screen.dart';
import 'package:social_app/screens/profile_screen.dart';
import 'package:social_app/utils/time_ago.dart';

class ReplyTile extends StatelessWidget {
  final Map<String, dynamic> replyData;
  final String? repliedToUsername;
  final VoidCallback onDelete;

  const ReplyTile({
    super.key,
    required this.replyData,
    this.repliedToUsername,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(replyData['userId'])
          .get(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final user = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final text = _displayText(
          (replyData['text'] ?? '').toString(),
          repliedToUsername,
        );
        final username = (user['username'] ?? replyData['username'] ?? 'Unknown')
            .toString();
        final photoUrl = (user['photoUrl'] ?? replyData['photoUrl'] ?? '')
            .toString();
        final isOwner =
            replyData['userId'] == FirebaseAuth.instance.currentUser?.uid;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: isOwner ? () => _confirmDelete(context) : null,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    final currentUid = FirebaseAuth.instance.currentUser!.uid;

                    if (replyData['userId'] == currentUid) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: currentUid),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(userId: replyData['userId']),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: const Color(0xFFEDE9F7),
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 14,
                            color: Color(0xFF7C3AED),
                          )
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
                          final currentUid =
                              FirebaseAuth.instance.currentUser!.uid;

                          if (replyData['userId'] == currentUid) {
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
                                  userId: replyData['userId'],
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          username,
                          style: const TextStyle(
                            color: Color(0xFF2E2A35),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.15,
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
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        TimeAgoHelper.format(
                          TimeAgoHelper.fromFirestore(replyData['createdAt']),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
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
    );
  }

  String _displayText(String value, String? repliedToUsername) {
    final text = value.trim();
    final replyTarget = repliedToUsername?.trim();

    if (replyTarget != null && replyTarget.isNotEmpty) {
      if (text.startsWith('@$replyTarget ')) {
        return text.substring(replyTarget.length + 2).trim();
      }

      if (text.startsWith('$replyTarget ')) {
        return text.substring(replyTarget.length + 1).trim();
      }
    }

    return text;
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reply?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
