import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_app/services/post_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../models/post.dart';
import '../screens/post_video_fullscreen_page.dart';
import '../utils/time_ago.dart';
import 'like_button.dart';
import 'comment_button.dart';
import '../screens/user_profile_screen.dart';
import '../screens/profile_screen.dart';
import '../services/follow_service.dart';
import '../services/post_navigation_service.dart';
import '../services/report_service.dart';
import '../services/share_service.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final Map<String, dynamic> userData;

  const PostCard({super.key, required this.post, required this.userData});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  Timer? _timeRefreshTimer;

  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    if (widget.post.type == 'video' && widget.post.videoUrl.isNotEmpty) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.post.videoUrl))
            ..initialize().then((_) {
              if (mounted) {
                setState(() {});
              }

              _videoController!.play();
              _videoController!.setLooping(true);
              _videoController!.setVolume(0);
            });
    }

    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timeRefreshTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildCategoryBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8C7FF)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF5B21B6),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMoodText(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF615A6F),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildMoodCategoryRow() {
    final mood = widget.post.mood.trim();
    final category = widget.post.category.trim();

    if (mood.isEmpty && category.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 7,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (category.isNotEmpty) _buildCategoryBadge(category),
          if (category.isNotEmpty && mood.isNotEmpty)
            const Text(
              "\u2022",
              style: TextStyle(
                color: Color(0xFF9A92A8),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (mood.isNotEmpty) _buildMoodText(mood),
        ],
      ),
    );
  }

  void _openVideoPost() {
    debugPrint('VIDEO TAP DETECTED');
    debugPrint('post id: ${widget.post.id}');
    debugPrint('video url: ${widget.post.videoUrl}');
    debugPrint('isWeb: $kIsWeb, platform: $defaultTargetPlatform');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostVideoFullscreenPage(post: widget.post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("TYPE: ${widget.post.type}");
    print("IMAGE URL: ${widget.post.imageUrl}");

    return GestureDetector(
      onTap: () {
        if (widget.post.type == 'video' && widget.post.videoUrl.isNotEmpty) {
          _openVideoPost();
        } else {
          PostNavigationService.openPost(context, postId: widget.post.id);
        }
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFE),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF0EDF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// USER + TIME
            GestureDetector(
              onTap: () {
                final currentUid = FirebaseAuth.instance.currentUser!.uid;

                if (widget.post.userId == currentUid) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: currentUid),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserProfileScreen(userId: widget.post.userId),
                    ),
                  );
                }
              },

              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.post.userId)
                    .snapshots(),

                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xfff3e8ff),
                          backgroundImage:
                              userData['photoUrl'] != null &&
                                  userData['photoUrl'].toString().isNotEmpty
                              ? NetworkImage(userData['photoUrl'])
                              : null,
                          child:
                              userData['photoUrl'] == null ||
                                  userData['photoUrl'].toString().isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Color(0xff8b5cf6),
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData['username'] ?? "user",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF201B27),
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                TimeAgoHelper.format(
                                  widget.post.createdAt,
                                  display: TimeAgoDisplay.feed,
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF7A7284),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              _buildMoodCategoryRow(),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        if (currentUser != null &&
                            currentUser!.uid != widget.post.userId)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUser!.uid)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox();
                              }
                              final data =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>;
                              final following = List<String>.from(
                                data['following'] ?? [],
                              );

                              final isFollowing = following.contains(
                                widget.post.userId,
                              );

                              return GestureDetector(
                                onTap: () async {
                                  if (isFollowing) {
                                    await FollowService().unfollowUser(
                                      currentUser!.uid,
                                      widget.post.userId,
                                    );
                                  } else {
                                    await FollowService().followUser(
                                      currentUser!.uid,
                                      widget.post.userId,
                                      currentUser!.displayName ?? "User",
                                    );
                                  }
                                },

                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),

                                  decoration: BoxDecoration(
                                    color: isFollowing
                                        ? const Color(0xFFF6F2FF)
                                        : const Color(0xFF8B5CF6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFDCCEFF),
                                    ),
                                  ),

                                  child: Text(
                                    isFollowing ? "Following" : "Follow",

                                    style: TextStyle(
                                      color: isFollowing
                                          ? const Color(0xFF7C3AED)
                                          : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(width: 4),

                        if (currentUser == null ||
                            currentUser!.uid != widget.post.userId)
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'report') {
                                await ReportService.reportPost(
                                  postId: widget.post.id,
                                  userId: currentUser!.uid,
                                  reason: 'Inappropriate Content',
                                );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Post reported'),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'report',
                                child: Text('Report Post'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // Text Post
            if (widget.post.text.isNotEmpty)
              Text(
                widget.post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: Color(0xFF27222E),
                ),
              ),

            const SizedBox(height: 13),

            /// IMAGE or VIDEO (POST)
            /// IMAGE POST
            if (widget.post.imageUrl.isNotEmpty && widget.post.type != 'video')
              GestureDetector(
                onDoubleTap: () {
                  PostService.toggleLike(widget.post.id);
                },

                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: widget.post.imageUrl,
                      width: double.infinity,
                      height: 350,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          height: 350,
                          width: double.infinity,
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 350,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (widget.post.type == 'video')
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.post.videoUrl.isNotEmpty ? _openVideoPost : null,
                onDoubleTap: () {
                  PostService.toggleLike(widget.post.id);
                },
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),

                    child:
                        _videoController != null &&
                            _videoController!.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: _videoController!.value.size.width,
                              height: _videoController!.value.size.height,
                              child: AbsorbPointer(
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.black,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            /// ACTIONS
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LikeButton(post: widget.post),
                  const SizedBox(width: 16),
                  CommentButton(
                    postId: widget.post.id,
                    postOwnerId: widget.post.userId,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: () {
                      ShareService.showShareOptions(context, widget.post);
                    },
                    icon: const Icon(Icons.ios_share_outlined),
                    color: const Color(0xFF5B21B6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
