import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

// removed unused import: login_screen.dart
import 'edit_profile_screen.dart';
import 'life_journey_details_screen.dart';

import '../services/cloudinary_service.dart';
import '../utils/route_observer.dart';
import '../widgets/profile/profile_about_card.dart';
import '../widgets/profile/profile_background.dart';
import '../widgets/profile/profile_life_journey_card.dart';
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
  String? work;
  String? family;
  String? goal;
  String? interests;
  String? location;
  String? relationship;
  String? birthday;
  String? lifeQuote;
  List<Map<String, dynamic>> lifeJourney = [];
  bool _isUploadingCoverImage = false;
  StreamSubscription<DocumentSnapshot>? _userSub;

  String get _profileUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.userId;

  bool get _hasCoverImage => _isValidCoverImageUrl(coverUrl);

  bool _isValidCoverImageUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;

    final path = uri.path.toLowerCase();
    if (path.contains('/image/upload')) return true;

    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.bmp');
  }

  String? _optionalProfileText(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! String) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _formatBirthday(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;

    final date = DateTime.tryParse(value.trim());
    if (date == null) return null;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  List<Map<String, dynamic>> _parseLifeJourney(dynamic value) {
    if (value is! List) return [];

    return value.whereType<Map>().map((item) {
      return {
        'year': (item['year'] ?? '').toString().trim(),
        'title': (item['title'] ?? '').toString().trim(),
      };
    }).where((item) {
      return item['year']!.isNotEmpty && item['title']!.isNotEmpty;
    }).toList();
  }

  void _applyUserData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      userName = data['username'] ?? 'User Name';
      bio = data['bio'] ?? '';
      photoUrl = data['photoUrl'] ?? '';
      coverUrl = data['coverUrl'] ?? '';
      work = _optionalProfileText(data, 'work');
      family = _optionalProfileText(data, 'family');
      goal = _optionalProfileText(data, 'goal');
      interests = _optionalProfileText(data, 'interests');
      location = _optionalProfileText(data, 'location');
      relationship = _optionalProfileText(data, 'relationship');
      birthday = _formatBirthday(data['birthday']);
      lifeQuote = _optionalProfileText(data, 'lifeQuote');
      lifeJourney = _parseLifeJourney(data['lifeJourney']);
    });
  }

  void _listenToUserData() {
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_profileUserId)
        .snapshots()
        .listen((doc) {
          final data = doc.data();
          if (data != null) {
            _applyUserData(data);
          }
        });
  }

  void editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    ).then((_) => loadProfile());
  }

  Future<void> loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_profileUserId)
        .get();

    final rawData = doc.data();
    if (rawData != null) {
      _applyUserData(rawData);
    }
  }

  @override
  void initState() {
    super.initState();
    _listenToUserData();
    loadProfile();
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
    _userSub?.cancel();
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
          if (_isUploadingCoverImage) ...[
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
          ],
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

  void _openCoverViewer() {
    if (!_hasCoverImage) {
      _pickCoverImage();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (context, setViewerState) {
            final hasCoverImage = _hasCoverImage;

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
              ProfileAboutCard(
                work: work,
                family: family,
                goal: goal,
                interests: interests,
                location: location,
                relationship: relationship,
                birthday: birthday,
                lifeQuote: lifeQuote,
              ),
              ProfileLifeJourneyCard(
                lifeJourney: lifeJourney,
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LifeJourneyDetailsScreen(
                        lifeJourney: lifeJourney,
                      ),
                    ),
                  );
                },
              ),
              const ProfileStats(),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: editProfile,
                child: const Text("Edit Profile"),
              ),
              const SizedBox(height: 18),
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
