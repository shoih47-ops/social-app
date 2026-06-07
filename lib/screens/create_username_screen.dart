import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'home_screen.dart';

class CreateUsernameScreen extends StatefulWidget {
  const CreateUsernameScreen({super.key});

  @override
  _CreateUsernameScreenState createState() => _CreateUsernameScreenState();
}

class _CreateUsernameScreenState extends State<CreateUsernameScreen> {
  final usernameController = TextEditingController();

  Future<void> saveUsername() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    String username = usernameController.text.trim();

    // Check username duplicate
    final check = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: usernameController.text)
        .get();

    if (check.docs.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Username already taken")));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': uid,
      'username': username,
      'bio': '',
      'photoUrl': '',
      'coverUrl': '',
      'coverType': 'image',
      'email': FirebaseAuth.instance.currentUser!.email,
      'followers': [],
      'following': [],
      'fcmToken': await FirebaseMessaging.instance.getToken(),
    }, SetOptions(merge: true));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Username")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(labelText: "Username"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveUsername,
              child: Text("Save Username"),
            ),
          ],
        ),
      ),
    );
  }
}
