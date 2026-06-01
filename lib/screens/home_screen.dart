import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'feed_screen.dart';
import 'create_post_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  void goToFeed() {
    setState(() {
      currentIndex = 0;
    });
  }

  Stream<int> getUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;

    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(user!.uid)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const FeedScreen(),
      CreatePostScreen(onPostSuccess: goToFeed),
      const NotificationScreen(),
      ProfileScreen(userId: FirebaseAuth.instance.currentUser!.uid),
    ];

    return Scaffold(
      body: screens[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        elevation: 0,
        backgroundColor: const Color(0xFFF8F8FA),
        selectedItemColor: Color(0xff8b5cf6),
        selectedFontSize: 12,
        unselectedItemColor: Colors.grey,
        unselectedFontSize: 11,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),

          BottomNavigationBarItem(
            icon: Container(
              margin: const EdgeInsets.only(bottom: 2),

              padding: const EdgeInsets.all(8),

              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(20),

                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff8b5cf6).withValues(alpha: 0.18),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),

              child: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),

            label: "",
          ),

          BottomNavigationBarItem(
            label: "Notify",
            icon: StreamBuilder<int>(
              stream: getUnreadCount(),
              builder: (context, snapshot) {
                int count = snapshot.data ?? 0;

                return Stack(
                  children: [
                    Icon(Icons.notifications),

                    if (count > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
