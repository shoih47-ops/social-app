import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io';

// removed unused import: login_screen.dart
import 'edit_profile_screen.dart';

import '../services/cloudinary_service.dart';
import '../services/profile_background_video_service.dart';
import '../utils/route_observer.dart';
import '../widgets/profile/profile_background.dart';
import '../widgets/profile/profile_screen_layout.dart';
import 'profile_video_fullscreen_page.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_stats.dart';
import '../widgets/profile/profile_posts_grid.dart';

import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final ValueNotifier<int>? indexNotifier;
  final int tabIndex;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.indexNotifier,
    this.tabIndex = 3,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RouteAware {
  String userName = "User Name";
  String bio = "";
  String? photoUrl;
  String coverUrl = '';
  String coverType = 'image';

  final ProfileBackgroundVideoService _backgroundVideoService =
      ProfileBackgroundVideoService();

  bool _videoLoaded = false;
  VoidCallback? _indexListener;

  void _notify() {
    if (mounted) setState(() {});
  }

  Future<void> getUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    final rawData = doc.data();
    if (rawData != null) {
      final data = rawData;

      setState(() {
        userName = data['username'] ?? '';
        bio = data['bio'] ?? '';
        photoUrl = data['photoUrl'] ?? '';
        coverUrl = data['coverUrl'] ?? '';
        coverType = data['coverType'] ?? 'image';
      });
    }

    // Do not auto-load background video here. Video is loaded when this
    // screen becomes active (visible) via the index notifier.
    _notify();
  }

  void editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final rawData = doc.data();
    if (rawData != null) {
      final data = rawData;

      setState(() {
        userName = data['username'] ?? 'User Name';
        bio = data['bio'] ?? 'My bio';
        photoUrl = data['photoUrl'];
        coverUrl = data['coverUrl'] ?? '';
        coverType = data['coverType'] ?? 'image';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
    getUserData();

    // Listen to tab index changes so we only load/play the background
    // video when this tab is active.
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
                      coverType = 'video';
                      coverUrl = _backgroundVideoService.backgroundVideoUrl;
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

      // Trigger once for the initial state.
      _indexListener!();
    } else {
      _backgroundVideoService
          .loadSavedVideo(widget.userId, onVideoUpdated: _notify)
          .then((_) {
            if (_backgroundVideoService.backgroundVideoUrl.isNotEmpty) {
              setState(() {
                coverType = 'video';
                coverUrl = _backgroundVideoService.backgroundVideoUrl;
              });
            }
          });
    }
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
    // Another route has been pushed atop this one — pause the background video.
    _backgroundVideoService.controller?.pause();
  }

  @override
  void didPopNext() {
    // Returned to this route — resume the background video only if this
    // tab is currently active.
    final isActive = widget.indexNotifier == null
        ? true
        : widget.indexNotifier!.value == widget.tabIndex;
    if (isActive) _backgroundVideoService.controller?.play();
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
    super.dispose();
  }

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final user = FirebaseAuth.instance.currentUser;
    final imageUrl = await CloudinaryService.uploadImage(file);

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'photoUrl': imageUrl,
    }, SetOptions(merge: true));

    setState(() {
      photoUrl = imageUrl;
    });
  }

  Future<void> pickAndSaveBackgroundVideo() async {
    await _backgroundVideoService.pickPreviewAndSave(
      onStateChanged: _notify,
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      onSuccess: (message) {
        if (!mounted) return;
        setState(() {
          coverType = 'video';
          coverUrl = _backgroundVideoService.backgroundVideoUrl;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  void _openFullscreenVideo() async {
    final url = _backgroundVideoService.backgroundVideoUrl;
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ProfileScreenLayout(
        coverType: coverType,
        coverUrl: coverUrl,
        backgroundVideoUrl: videoService.backgroundVideoUrl,
        videoController: videoService.controller,
        isUploading: videoService.isUploading,
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
              ProfileHeader(
                photoUrl: photoUrl,
                userName: userName,
                bio: bio,
                onPickImage: pickImage,
              ),
              const ProfileStats(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: editProfile,
                child: const Text("Edit Profile"),
              ),
              const SizedBox(height: 30),
              const ProfilePostsGrid(),
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
                    // If a background video exists, open the existing fullscreen viewer.
                    if (videoService.backgroundVideoUrl.isNotEmpty) {
                      _openFullscreenVideo();
                      return;
                    }

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
              Transform.translate(
                offset: const Offset(0, -104),
                child: ProfileCoverActions(
                  hasVideo: videoService.hasVideo,
                  isUploading: videoService.isUploading,
                  backgroundVideoUrl: videoService.backgroundVideoUrl,
                  onPickVideo: pickAndSaveBackgroundVideo,
                  // Note: intentionally NOT passing `onFullscreen` to remove the fullscreen button.
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
