import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/post_navigation_service.dart';
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
        return "liked your post";
      case "comment":
        return "commented on your post";
      case "follow":
        return "started following you";
      case "reply":
        return "replied to your comment";
      case "tagged":
        return "tagged you in a moment.";
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

          if (docs.isEmpty)
            return const Center(child: Text("No notifications"));

          final now = DateTime.now();
          final today = <QueryDocumentSnapshot>[];
          final yesterday = <QueryDocumentSnapshot>[];
          final earlier = <QueryDocumentSnapshot>[];

          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final date = TimeAgoHelper.fromFirestore(
              data['createdAt'],
            ).toDate();
            final diff = DateTime(
              now.year,
              now.month,
              now.day,
            ).difference(DateTime(date.year, date.month, date.day)).inDays;

            if (diff == 0) {
              today.add(d);
            } else if (diff == 1) {
              yesterday.add(d);
            } else {
              earlier.add(d);
            }
          }

          Widget buildSection(String title, List<QueryDocumentSnapshot> items) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff6b21a8),
                    ),
                  ),
                ),
                ...items.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  return Dismissible(
                    key: Key(doc.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(user.uid)
                          .collection('items')
                          .doc(doc.id)
                          .delete();

                      return true;
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(data['fromUserId'])
                          .get(),
                      builder: (context, userSnap) {
                        final userData =
                            userSnap.hasData && userSnap.data!.data() != null
                            ? userSnap.data!.data() as Map<String, dynamic>
                            : null;

                        final isRead = data['isRead'] == true;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isRead
                                ? Colors.white
                                : const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              if (isRead)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                            ],
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            leading:
                                userData != null &&
                                    (userData['photoUrl'] != null &&
                                        userData['photoUrl'] != '')
                                ? CircleAvatar(
                                    radius: 22,
                                    backgroundImage: NetworkImage(
                                      userData['photoUrl'],
                                    ),
                                  )
                                : Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.04),
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
                                    text: "${data['fromUsername']} ",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: getText(data['type']),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            subtitle: Text(
                              TimeAgoHelper.format(
                                TimeAgoHelper.fromFirestore(data['createdAt']),
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            onTap: () async {
                              final me = FirebaseAuth.instance.currentUser;

                              // mark read
                              await FirebaseFirestore.instance
                                  .collection('notifications')
                                  .doc(me!.uid)
                                  .collection('items')
                                  .doc(doc.id)
                                  .update({'isRead': true});

                              final type = data['type'];

                              if (type == 'follow') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(
                                      userId: data['fromUserId'],
                                    ),
                                  ),
                                );
                              } else {
                                await PostNavigationService.openPost(
                                  context,
                                  postId: data['postId'] ?? '',
                                  openComments:
                                      type == 'comment' || type == 'reply',
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ],
            );
          }

          final sections = <Widget>[];
          if (today.isNotEmpty) sections.add(buildSection('Today', today));
          if (yesterday.isNotEmpty)
            sections.add(buildSection('Yesterday', yesterday));
          if (earlier.isNotEmpty)
            sections.add(buildSection('Earlier', earlier));

          return ListView(children: sections);
        },
      ),
    );
  }
}
