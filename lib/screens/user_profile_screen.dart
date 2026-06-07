import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/route_observer.dart';

import '../services/follow_service.dart';
import '../services/profile_background_video_service.dart';
import '../widgets/profile/profile_background.dart';
import '../widgets/profile/profile_screen_layout.dart';
import 'profile_video_fullscreen_page.dart';
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
  String coverType = 'image';
  String backgroundVideoUrl = '';

  String currentUsername = "";

  final FollowService followService = FollowService();
  final ProfileBackgroundVideoService _backgroundVideoService =
      ProfileBackgroundVideoService();
  bool isFollowing = false;
  StreamSubscription<DocumentSnapshot>? _currentUserSub;
  bool _videoLoaded = false;
  VoidCallback? _indexListener;

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

    // Listen to tab index changes to lazily load/play/pause the background
    // video only when this tab is active.
    if (widget.indexNotifier != null) {
      _indexListener = () {
        final isActive = widget.indexNotifier!.value == widget.tabIndex;
        if (isActive) {
          if (!_videoLoaded) {
            _backgroundVideoService
                .loadSavedVideo(widget.userId, onVideoUpdated: _notify)
                .then((_) {
                  _videoLoaded = true;
                  if (_backgroundVideoService.backgroundVideoUrl.isNotEmpty) {
                    setState(() {
                      backgroundVideoUrl =
                          _backgroundVideoService.backgroundVideoUrl;
                      coverType = 'video';
                      coverUrl = backgroundVideoUrl;
                    });
                  }
                });
          } else {
            _backgroundVideoService.controller?.play();
          }
        } else {
          _backgroundVideoService.controller?.pause();
        }
      };
      widget.indexNotifier!.addListener(_indexListener!);
      // Trigger initial state
      _indexListener!();
    }
  }

  @override
  void dispose() {
    if (widget.indexNotifier != null && _indexListener != null) {
      widget.indexNotifier!.removeListener(_indexListener!);
    }
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    _backgroundVideoService.dispose();
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
  void didPushNext() {
    _backgroundVideoService.controller?.pause();
  }

  @override
  void didPopNext() {
    final isActive = widget.indexNotifier == null
        ? true
        : widget.indexNotifier!.value == widget.tabIndex;
    if (isActive) _backgroundVideoService.controller?.play();
  }

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

        await _backgroundVideoService.loadFromUserData(data);

        username = data['username'] ?? '';
        bio = data['bio'] ?? '';
        photoUrl = data['photoUrl'] as String?;
        coverUrl = data['coverUrl'] is String ? data['coverUrl'] as String : '';
        coverType = data['coverType'] is String
            ? data['coverType'] as String
            : 'image';

        backgroundVideoUrl = ProfileBackgroundVideoService.readVideoUrlFromData(
          data,
        );
        if (backgroundVideoUrl.isNotEmpty) {
          coverType = 'video';
          coverUrl = backgroundVideoUrl;
        }
      }
    }

    // Background video is loaded lazily when this screen becomes active
    // (via the index notifier). Do not auto-load here to avoid playback on
    // app startup.

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

  void _openFullscreenVideo() async {
    final url = backgroundVideoUrl.isNotEmpty
        ? backgroundVideoUrl
        : _backgroundVideoService.backgroundVideoUrl;
    if (url.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileVideoFullscreenPage(videoUrl: url),
      ),
    );
    _backgroundVideoService.controller?.play();
  }

  @override
  Widget build(BuildContext context) {
    final videoService = _backgroundVideoService;
    final videoUrl = backgroundVideoUrl.isNotEmpty
        ? backgroundVideoUrl
        : videoService.backgroundVideoUrl;

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
        coverType: coverType,
        coverUrl: coverUrl,
        backgroundVideoUrl: videoUrl,
        videoController: videoService.controller,
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
                    // Open existing fullscreen viewer for video if available.
                    if (videoUrl.isNotEmpty) {
                      _openFullscreenVideo();
                      return;
                    }

                    // Otherwise, if there's a cover image, show it full-screen.
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
              ProfileCoverActions(
                hasVideo: videoService.hasVideo,
                backgroundVideoUrl: videoUrl,
                // Intentionally not passing `onFullscreen` to remove the fullscreen button.
              ),
            ],
          ),
        ),
      ),
    );
  }
}
