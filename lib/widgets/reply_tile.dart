import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:social_app/screens/user_profile_screen.dart';
import 'package:social_app/screens/profile_screen.dart';

class ReplyTile extends StatelessWidget {
  final Map<String, dynamic> replyData;
  final VoidCallback onDelete;

  const ReplyTile({super.key, required this.replyData, required this.onDelete});

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

        final user = snapshot.data!.data() as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.only(left: 45, top: 6),
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
                  radius: 12,
                  backgroundImage:
                      user['photoUrl'] != null && user['photoUrl'] != ''
                      ? NetworkImage(user['photoUrl'])
                      : null,
                  child: (user['photoUrl'] == null || user['photoUrl'] == '')
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
              ),

              const SizedBox(width: 8),

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
                              builder: (_) => ProfileScreen(userId: currentUid),
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
                        user['username'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    Builder(
                      builder: (context) {
                        final text = replyData['text'] ?? '';

                        final firstSpace = text.indexOf(' ');

                        String mention = '';
                        String message = text;

                        if (firstSpace != -1) {
                          mention = text.substring(0, firstSpace);
                          message = text.substring(firstSpace + 1);
                        }

                        return RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: mention,
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),

                              TextSpan(
                                text: message,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    Text(
                      timeago.format(
                        (replyData['createdAt'] as Timestamp).toDate(),
                      ),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              if (replyData['userId'] == FirebaseAuth.instance.currentUser!.uid)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete Reply')),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
