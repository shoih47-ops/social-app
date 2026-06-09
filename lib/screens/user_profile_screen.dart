import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/route_observer.dart';

import '../services/follow_service.dart';
import '../widgets/profile/profile_screen_layout.dart';
import '../widgets/profile/user_profile_header.dart';
import '../widgets/profile/user_profile_stats.dart';
import '../widgets/profile/user_profile_posts_grid.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final ValueNotifier<int>? indexNotifier;
  final int tabIndex;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.indexNotifier,
    this.tabIndex = 3,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with RouteAware {
  String username = "";
  String bio = "";
  String? photoUrl;
  String coverUrl = '';

  String currentUsername = "";

  final FollowService followService = FollowService();
  bool isFollowing = false;
  StreamSubscription<DocumentSnapshot>? _currentUserSub;

  void _notify() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
    // Listen to current user's doc for realtime 'following' updates so this
    // profile UI stays in sync with other parts of the app.
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      _currentUserSub = FirebaseFirestore.instance
          .collection('users')
          .doc(current.uid)
          .snapshots()
          .listen((snap) {
            if (!snap.exists) return;
            final data = snap.data();
            if (data == null) return;
            final myFollowing = List<String>.from(data['following'] ?? []);
            final nowFollowing = myFollowing.contains(widget.userId);
            if (mounted) {
              setState(() {
                isFollowing = nowFollowing;
              });
            }
          });
    }
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    _currentUserSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {}

  @override
  void didPopNext() {}

  Future<void> loadUserData() async {
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();

    final rawCurrentData = currentUserDoc.data();
    if (rawCurrentData != null) {
      final currentData = rawCurrentData;
      currentUsername = currentData['username'] ?? '';
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (userDoc.exists) {
      final rawData = userDoc.data();
      if (rawData != null) {
        final data = rawData;

        username = data['username'] ?? '';
        bio = data['bio'] ?? '';
        photoUrl = data['photoUrl'] as String?;
        final rawCoverUrl = data['coverUrl'];
        coverUrl = rawCoverUrl is String ? rawCoverUrl.trim() : '';
      }
    }

    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();

    final rawMyData = myDoc.data();
    if (rawMyData != null) {
      final myData = rawMyData;
      final myFollowing = myData['following'] ?? [];
      isFollowing = myFollowing.contains(widget.userId);
    }

    _notify();
  }

  Future<void> _toggleFollow() async {
    final myId = FirebaseAuth.instance.currentUser!.uid;

    if (isFollowing) {
      await followService.unfollowUser(myId, widget.userId);
    } else {
      await followService.followUser(myId, widget.userId, currentUsername);
    }

    await loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(username.isEmpty ? "Profile" : username),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: ProfileScreenLayout(
        coverUrl: coverUrl,
        content: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              UserProfileHeader(
                photoUrl: photoUrl,
                userName: username,
                bio: bio,
              ),
              UserProfileStats(userId: widget.userId),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _toggleFollow,
                child: Text(isFollowing ? "Following" : "Follow"),
              ),
              const SizedBox(height: 30),
              UserProfilePostsGrid(userId: widget.userId),
              const SizedBox(height: 100),
            ],
          ),
        ),
        coverActions: SizedBox(
          height: 260,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // If there's a cover image, show it full-screen.
                    if (coverUrl.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            body: SafeArea(
                              top: false,
                              bottom: false,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.of(context).pop(),
                                child: Center(
                                  child: InteractiveViewer(
                                    child: Image.network(
                                      coverUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
