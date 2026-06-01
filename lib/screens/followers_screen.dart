import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_app/screens/profile_screen.dart';
import 'user_profile_screen.dart';

class FollowersScreen extends StatelessWidget {
  final String userId;
  const FollowersScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Followers")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final rawData = snapshot.data!.data();
          if (rawData == null) {
            return const SizedBox();
          }

          final data = rawData as Map<String, dynamic>;
          List followers = data['followers'] ?? [];

          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followers[index])
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();

                  final rawUserData = userSnap.data!.data();
                  if (rawUserData == null) return const SizedBox();

                  final userData = rawUserData as Map<String, dynamic>;
                  final userDoc = userSnap.data!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(userData['photoUrl'] ?? ''),
                    ),
                    title: Text(userData['username'] ?? ''),

                    onTap: () {
                      final currentUser = FirebaseAuth.instance.currentUser;

                      if (currentUser != null &&
                          currentUser.uid == userDoc.id) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: userId),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UserProfileScreen(userId: userDoc.id),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
