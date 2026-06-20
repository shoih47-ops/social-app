import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'create_username_screen.dart';

class AuthGate extends StatelessWidget {
  final String? initialPostId;

  const AuthGate({super.key, this.initialPostId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // not logged in
        if (!snapshot.hasData) {
          return LoginScreen(initialPostId: initialPostId);
        }

        final user = snapshot.data!;

        // check user document
        return FutureBuilder(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snap.data!.data();

            if (data == null ||
                data['username'] == null ||
                data['username'] == '') {
              return CreateUsernameScreen(initialPostId: initialPostId);
            }

            return HomeScreen(initialPostId: initialPostId);
          },
        );
      },
    );
  }
}
