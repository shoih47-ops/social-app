import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../screens/followers_screen.dart';
import '../../screens/following_screen.dart';

class UserProfileStats extends StatelessWidget {
  final String userId;

  const UserProfileStats({
    super.key,
    required this.userId,
  });

  Widget _buildStat(String label, String count) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final data = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final followers = data['followers'] is List
            ? data['followers'] as List
            : [];
        final following = data['following'] is List
            ? data['following'] as List
            : [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, postsSnapshot) {
            final postCount = postsSnapshot.hasData
                ? postsSnapshot.data!.docs.length
                : 0;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 90,
                  child: _buildStat("Posts", postCount.toString()),
                ),
                SizedBox(
                  width: 90,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowersScreen(userId: userId),
                        ),
                      );
                    },
                    child: _buildStat("Followers", followers.length.toString()),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowingScreen(userId: userId),
                        ),
                      );
                    },
                    child: _buildStat("Following", following.length.toString()),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
