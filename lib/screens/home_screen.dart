import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'feed_screen.dart';
import 'create_post_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import '../services/fcm_service.dart';
import '../services/post_navigation_service.dart';

class HomeScreen extends StatefulWidget {
  final String? initialPostId;

  const HomeScreen({super.key, this.initialPostId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  late final List<Widget> _screens;
  late final ValueNotifier<int> _currentIndexNotifier;

  void goToFeed() {
    setState(() {
      currentIndex = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    FcmService.instance.syncTokenForCurrentUser();
    _currentIndexNotifier = ValueNotifier<int>(currentIndex);
    _screens = [
      const FeedScreen(),
      CreatePostScreen(onPostSuccess: goToFeed),
      const NotificationScreen(),
      ProfileScreen(
        userId: FirebaseAuth.instance.currentUser!.uid,
        indexNotifier: _currentIndexNotifier,
        tabIndex: 3,
      ),
    ];
    _openInitialPostLink();
  }

  void _openInitialPostLink() {
    final postId = widget.initialPostId;
    if (postId == null || postId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PostNavigationService.openPost(context, postId: postId);
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
    return WillPopScope(
      onWillPop: () async {
        // If we're not on the first tab, switch to it instead of popping.
        if (currentIndex != 0) {
          setState(() {
            currentIndex = 0;
            _currentIndexNotifier.value = 0;
          });
          return false; // prevent pop
        }

        // Otherwise allow system back (exit app or pop non-tab routes).
        return true;
      },
      child: Scaffold(
        body: IndexedStack(index: currentIndex, children: _screens),

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
            debugPrint('OLD: $currentIndex');
            debugPrint('NEW: $index');

            setState(() {
              currentIndex = index;
              _currentIndexNotifier.value = index;
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
                  Icons.camera_alt,
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
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
      ),
    );
  }

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    super.dispose();
  }
}
