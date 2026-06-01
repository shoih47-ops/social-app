import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'post_detail_screen.dart';
import '../utils/time_ago.dart';

import 'user_profile_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String getText(String type) {
    switch (type) {
      case "like":
        return "connected with your story";
      case "comment":
        return "shared a thought on your story";
      case "follow":
        return "started following your journey";
      case "reply":
        return "responded to your thoughts";
      default:
        return "";
    }
  }

  Widget getIcon(String type) {
    switch (type) {
      case "like":
        return const Icon(Icons.favorite, color: Colors.black87, size: 20);
      case "comment":
        return const Icon(Icons.comment, color: Colors.black87, size: 20);
      case "follow":
        return const Icon(Icons.person_add_alt_1, color: Colors.black87);
      case "reply":
        return const Icon(Icons.reply_rounded, color: Colors.black87, size: 20);
      default:
        return const Icon(
          Icons.notifications_none,
          color: Colors.black87,
          size: 20,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("User not logged in"));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .doc(user.uid)
            .collection('items')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          print(user.uid);

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              return Dismissible(
                key: Key(docs[index].id),

                direction: DismissDirection.endToStart,

                confirmDismiss: (_) async {
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(user.uid)
                      .collection('items')
                      .doc(docs[index].id)
                      .delete();

                  return true;
                },

                background: Container(
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: Icon(Icons.delete, color: Colors.white),
                ),

                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: getIcon(data['type'])),
                    ),

                    title: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(
                            text: "${data['fromUsername']}  ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          TextSpan(
                            text: getText(data['type']),
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    subtitle: Text(
                      timeAgo((data['createdAt'] as Timestamp).toDate()),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),

                    tileColor: data['isRead'] == true
                        ? null
                        : Colors.grey.withOpacity(0.1),

                    onTap: () async {
                      final user = FirebaseAuth.instance.currentUser;

                      // Mark as read
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(user!.uid)
                          .collection('items')
                          .doc(docs[index].id)
                          .update({'isRead': true});

                      final type = data['type'];

                      if (type == 'follow') {
                        // go to user profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UserProfileScreen(userId: data['fromUserId']),
                          ),
                        );
                      } else {
                        // like / comment -> go to post
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PostDetailScreen(postId: data['postId']),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
