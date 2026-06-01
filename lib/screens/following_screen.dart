import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart';

class FollowingScreen extends StatelessWidget {
  final String userId;
  const FollowingScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Following")),
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
          List following = data['following'] ?? [];

          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(following[index])
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();

                  final rawUserData = userSnap.data!.data();
                  if (rawUserData == null) return const SizedBox();

                  final userData = rawUserData as Map<String, dynamic>;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(userData['photoUrl'] ?? ''),
                    ),
                    title: Text(userData['username'] ?? ''),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(userId: following[index]),
                        ),
                      );
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
