import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../utils/time_ago.dart';
import '../widgets/post_card.dart';

import 'create_post_screen.dart';
import 'edit_profile_screen.dart';
import 'user_search_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const SizedBox();
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),

      appBar: AppBar(
        titleSpacing: 10,
        actions: [
          IconButton(
            tooltip: 'Search users',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
            icon: const Icon(Icons.search),
          ),
        ],
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            );
          },
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EEF8),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFE5DDF6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: const Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 21,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Share a real moment from your life...",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF6B6475),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              );
            }

            final posts = snapshot.data!.docs;

            if (posts.isEmpty) {
              return Column(
                children: [
                  _CompleteProfilePrompt(userId: currentUser.uid),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 70,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No posts yet",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Share your first real moment ✨",
                      style: const TextStyle(color: Colors.grey),
                    ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                // Just wait for a moment to simulate refresh
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 2, bottom: 100),
                physics: const BouncingScrollPhysics(),
                cacheExtent: 1000,
                itemCount: posts.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CompleteProfilePrompt(userId: currentUser.uid);
                  }

                  if (index == posts.length + 1) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: const Center(
                        child: Text("No more stories for now"),
                      ),
                    );
                  }

                  final postIndex = index - 1;
                  final data = posts[postIndex].data() as Map<String, dynamic>;

                  final post = Post(
                    id: posts[postIndex].id,
                    text: data['text'] ?? '',
                    imageUrl: data['imageUrl'] ?? '',
                    imageUrls: List<String>.from(data['imageUrls'] ?? []),
                    videoUrl: data['videoUrl'] ?? '',
                    type: data['type'] ?? '',
                    comments: List.from(data['comments'] ?? []),
                    likedBy: List<String>.from(data['likes'] ?? []),
                    createdAt: TimeAgoHelper.fromFirestore(data['createdAt']),
                    userId: data['userId'] ?? '',
                    content: data['content'] ?? '',
                    username: data['username'] ?? 'user',
                    userPhoto: data['photoUrl'] ?? '',
                    mood: data['mood'] ?? '',
                    category: data['category'] ?? '',
                    taggedUserIds: List<String>.from(
                      data['taggedUserIds'] ?? [],
                    ),
                  );

                  final card = PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    userData: data,
                  ).animate().fadeIn(duration: 400.ms).slideY(
                    begin: 0.05,
                    end: 0,
                  );

                  return ValueListenableBuilder<Set<String>>(
                    valueListenable: PostService.deletingVideoPostIds,
                    builder: (context, deletingVideoPostIds, child) {
                      if (post.type == 'video' &&
                          deletingVideoPostIds.contains(post.id)) {
                        return const SizedBox.shrink();
                      }

                      return child!;
                    },
                    child: card,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompleteProfilePrompt extends StatefulWidget {
  final String userId;

  const _CompleteProfilePrompt({required this.userId});

  @override
  State<_CompleteProfilePrompt> createState() => _CompleteProfilePromptState();
}

class _CompleteProfilePromptState extends State<_CompleteProfilePrompt> {
  static const Duration _dismissDuration = Duration(days: 7);
  bool _hasLoadedReminderState = false;
  bool _isDismissed = false;
  bool _isCompletedPermanently = false;

  String get _dismissedAtKey =>
      'complete_profile_prompt_dismissed_at_${widget.userId}';
  String get _completedKey =>
      'complete_profile_prompt_completed_${widget.userId}';

  @override
  void initState() {
    super.initState();
    _loadDismissState();
  }

  Future<void> _loadDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedAt = prefs.getInt(_dismissedAtKey);
    final isCompletedPermanently = prefs.getBool(_completedKey) ?? false;
    final isDismissed =
        dismissedAt != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(dismissedAt),
            ) <
            _dismissDuration;

    if (!mounted) return;
    setState(() {
      _hasLoadedReminderState = true;
      _isDismissed = isDismissed;
      _isCompletedPermanently = isCompletedPermanently;
    });
  }

  Future<void> _dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _dismissedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    if (!mounted) return;
    setState(() {
      _isDismissed = true;
    });
  }

  Future<void> _markProfileComplete() async {
    if (_isCompletedPermanently) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedAtKey);
    await prefs.setBool(_completedKey, true);

    if (!mounted) return;
    setState(() {
      _isCompletedPermanently = true;
      _isDismissed = false;
    });
  }

  bool _isProfileIncomplete(Map<String, dynamic> data) {
    final username = (data['username'] ?? '').toString().trim();
    final displayName =
        (data['displayName'] ?? data['name'] ?? username).toString().trim();
    final profilePhoto = (data['photoUrl'] ?? data['photo'] ?? '')
        .toString()
        .trim();

    return displayName.isEmpty || username.isEmpty || profilePhoto.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!_hasLoadedReminderState || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return const SizedBox.shrink();
        }

        if (_isCompletedPermanently) {
          return const SizedBox.shrink();
        }

        if (!_isProfileIncomplete(data)) {
          _markProfileComplete();
          return const SizedBox.shrink();
        }

        if (_isDismissed) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EEF8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5DDF6)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  color: Color(0xFF8B5CF6),
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Complete your profile to help others know you better.",
                    style: TextStyle(
                      color: Color(0xFF4B4458),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF8B5CF6),
                  size: 22,
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismissPrompt,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF8B5CF6),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
