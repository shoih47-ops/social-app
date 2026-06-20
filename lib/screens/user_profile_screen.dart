import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/route_observer.dart';
import 'life_journey_details_screen.dart';

import '../services/follow_service.dart';
import '../widgets/profile/profile_about_card.dart';
import '../widgets/profile/profile_life_journey_card.dart';
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
  String? work;
  String? family;
  String? goal;
  String? interests;
  String? location;
  String? nationality;
  String? relationship;
  String? birthday;
  String? lifeQuote;
  List<Map<String, dynamic>> lifeJourney = [];

  String currentUsername = "";

  final FollowService followService = FollowService();
  bool isFollowing = false;
  StreamSubscription<DocumentSnapshot>? _currentUserSub;
  final ScrollController _scrollController = ScrollController();
  double _appBarTransition = 0;

  void _handleProfileScroll() {
    final nextTransition = ((_scrollController.offset - 90) / 90).clamp(
      0.0,
      1.0,
    );

    if ((nextTransition - _appBarTransition).abs() < 0.01) return;

    setState(() {
      _appBarTransition = nextTransition;
    });
  }

  void _notify() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleProfileScroll);
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
    _scrollController.removeListener(_handleProfileScroll);
    _scrollController.dispose();
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
        work = _optionalProfileText(data, 'work');
        family = _optionalProfileText(data, 'family');
        goal = _optionalProfileText(data, 'goal');
        interests = _optionalProfileText(data, 'interests');
        location = _optionalProfileText(data, 'location');
        nationality = _optionalProfileText(data, 'nationality');
        relationship = _optionalProfileText(data, 'relationship');
        birthday = _formatBirthday(data['birthday']);
        lifeQuote = _optionalProfileText(data, 'lifeQuote');
        lifeJourney = _parseLifeJourney(data['lifeJourney']);
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

    return value
        .whereType<Map>()
        .map((item) {
          return {
            'year': (item['year'] ?? '').toString().trim(),
            'startYear': (item['startYear'] ?? item['year'] ?? '')
                .toString()
                .trim(),
            'endYear': (item['endYear'] ?? '').toString().trim(),
            'title': (item['title'] ?? '').toString().trim(),
            'category': (item['category'] ?? 'Other').toString().trim(),
            'isOngoing': item['isOngoing'] == true || item['ongoing'] == true,
          };
        })
        .where((item) {
          return (item['startYear'] as String).isNotEmpty &&
              (item['title'] as String).isNotEmpty;
        })
        .toList();
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
    final appBarBackground = Color.lerp(
      Colors.transparent,
      Colors.white,
      _appBarTransition,
    );
    final appBarForeground = Color.lerp(
      Colors.white,
      Colors.black,
      _appBarTransition,
    )!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(username.isEmpty ? "Profile" : username),
        backgroundColor: appBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: appBarForeground),
        titleTextStyle: TextStyle(color: appBarForeground, fontSize: 20),
      ),
      body: ProfileScreenLayout(
        coverUrl: coverUrl,
        scrollController: _scrollController,
        onCoverTap: coverUrl.isNotEmpty
            ? () {
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
            : null,
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
              ProfileAboutCard(
                work: work,
                family: family,
                goal: goal,
                interests: interests,
                location: location,
                nationality: nationality,
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
                      builder: (_) =>
                          LifeJourneyDetailsScreen(lifeJourney: lifeJourney),
                    ),
                  );
                },
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
      ),
    );
  }
}
