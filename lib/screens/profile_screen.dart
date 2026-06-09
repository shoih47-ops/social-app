import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io';

// removed unused import: login_screen.dart
import 'edit_profile_screen.dart';

import '../services/cloudinary_service.dart';
import '../utils/route_observer.dart';
import '../widgets/profile/profile_background.dart';
import '../widgets/profile/profile_screen_layout.dart';
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
  bool _isUploadingCoverImage = false;

  bool get _hasCoverImage => coverUrl.trim().isNotEmpty;

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
      });
    }

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
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
    getUserData();
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
    // Another route has been pushed atop this one.
  }

  @override
  void didPopNext() {
    // Returned to this route.
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
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

  Future<void> _pickCoverImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingCoverImage = true);

    try {
      final file = File(pickedFile.path);
      final user = FirebaseAuth.instance.currentUser;
      final imageUrl = await CloudinaryService.uploadImage(file);

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'coverUrl': imageUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        coverUrl = imageUrl;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload cover photo')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingCoverImage = false);
    }
  }

  Widget _buildCoverPlaceholder() {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70),
            ),
            child: _isUploadingCoverImage
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
          ),
          const SizedBox(height: 8),
          const Text(
            '+ Add Cover Photo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Tap to add a background image',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverEditButton() {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: _isUploadingCoverImage ? null : _pickCoverImage,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _isUploadingCoverImage
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[700],
                  ),
                )
              : Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: Colors.grey[800],
                ),
        ),
      ),
    );
  }

  void _openCoverViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (context, setViewerState) {
            final hasCoverImage = coverUrl.trim().isNotEmpty;

            return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                top: false,
                bottom: false,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: hasCoverImage
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                return InteractiveViewer(
                                  minScale: 1,
                                  maxScale: 4,
                                  constrained: false,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: Image.network(
                                      coverUrl,
                                      fit: BoxFit.contain,
                                      alignment: Alignment.topCenter,
                                    ),
                                  ),
                                );
                              },
                            )
                          : const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: profileBackgroundGradient,
                              ),
                              child: SizedBox.expand(),
                            ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 32,
                      child: Center(
                        child: ElevatedButton(
                          onPressed: _isUploadingCoverImage
                              ? null
                              : () async {
                                  await _pickCoverImage();
                                  if (mounted) {
                                    setViewerState(() {});
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: _isUploadingCoverImage
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  hasCoverImage
                                      ? 'Change Cover Photo'
                                      : 'Add Cover Photo',
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: _hasCoverImage ? _openCoverViewer : _pickCoverImage,
                ),
              ),
              if (!_hasCoverImage)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 70,
                  child: Center(child: _buildCoverPlaceholder()),
                )
              else
                Positioned(
                  right: 16,
                  bottom: 78,
                  child: _buildCoverEditButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
