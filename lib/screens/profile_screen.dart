import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'login_screen.dart';

import '../services/cloudinary_service.dart';
import '../services/profile_background_video_service.dart';
import '../widgets/profile/profile_background.dart';
import '../widgets/profile/profile_screen_layout.dart';
import 'profile_video_fullscreen_page.dart';
import '../widgets/profile/profile_header.dart';
import '../widgets/profile/profile_stats.dart';
import '../widgets/profile/profile_posts_grid.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = "User Name";
  String bio = "";
  String? photoUrl;
  String coverUrl = '';
  String coverType = 'image';

  final ProfileBackgroundVideoService _backgroundVideoService =
      ProfileBackgroundVideoService();

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

    await _backgroundVideoService.loadSavedVideo(
      widget.userId,
      onVideoUpdated: _notify,
    );
    if (_backgroundVideoService.backgroundVideoUrl.isNotEmpty) {
      coverType = 'video';
      coverUrl = _backgroundVideoService.backgroundVideoUrl;
    }
    _notify();
  }

  void editProfile() {
    final nameController = TextEditingController(text: userName);
    final bioController = TextEditingController(text: bio);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Profile"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: bioController,
                decoration: const InputDecoration(labelText: "Bio"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .set({
                      'username': nameController.text,
                      'bio': bioController.text,
                    }, SetOptions(merge: true));

                setState(() {
                  userName = nameController.text;
                  bio = bioController.text;
                });

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
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
  }

  @override
  void dispose() {
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
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
        coverActions: ProfileCoverActions(
          hasVideo: videoService.hasVideo,
          isUploading: videoService.isUploading,
          backgroundVideoUrl: videoService.backgroundVideoUrl,
          onPickVideo: pickAndSaveBackgroundVideo,
          onFullscreen: _openFullscreenVideo,
        ),
      ),
    );
  }
}
