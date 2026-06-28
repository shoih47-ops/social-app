import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'tagged_people_section.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final Map<String, dynamic> userData;

  const PostCard({super.key, required this.post, required this.userData});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static final BoxDecoration _cardDecoration = BoxDecoration(
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
  );

  VideoPlayerController? _videoController;
  late Stream<DocumentSnapshot> _authorStream;
  Stream<DocumentSnapshot>? _currentUserStream;

  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _authorStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.post.userId)
        .snapshots();
    if (currentUser != null) {
      _currentUserStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots();
    }

    if (widget.post.type == 'video' && widget.post.videoUrl.isNotEmpty) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.post.videoUrl))
            ..initialize().then((_) {
              if (mounted) {
                setState(() {});
              }
            });
    }
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.userId != widget.post.userId) {
      _authorStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post.userId)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildMoodChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8C7FF)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF5B21B6),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCategoryLabel(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF8A8392),
        fontSize: 11,
        fontWeight: FontWeight.w500,
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
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (mood.isNotEmpty) _buildMoodChip(mood),
          if (mood.isNotEmpty && category.isNotEmpty)
            const Text(
              "\u2022",
              style: TextStyle(
                color: Color(0xFFB0A9B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (category.isNotEmpty) _buildCategoryLabel(category),
        ],
      ),
    );
  }

  void _openVideoPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostVideoFullscreenPage(post: widget.post),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildMediaCountBadge({
    required IconData icon,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoDurationBadge(Duration duration) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _formatDuration(duration),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildPlayOverlay() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 44,
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    final thumbnailUrl = widget.post.imageUrl.trim();

    if (thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.black),
        errorWidget: (context, url, error) => Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.videocam_rounded,
              color: Colors.white70,
              size: 42,
            ),
          ),
        ),
      );
    }

    if (_videoController != null && _videoController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: AbsorbPointer(
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    return Container(color: Colors.black);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.post.effectiveImageUrls;
    final isVideo = widget.post.type == 'video';

    return GestureDetector(
      onTap: () {
        if (isVideo && widget.post.videoUrl.isNotEmpty) {
          _openVideoPost();
        } else {
          PostNavigationService.openPost(context, postId: widget.post.id);
        }
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        decoration: _cardDecoration,

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
                stream: _authorStream,

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

                              _FeedTimestamp(
                                createdAt: widget.post.createdAt,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (currentUser != null &&
                                currentUser!.uid != widget.post.userId)
                              StreamBuilder<DocumentSnapshot>(
                                stream: _currentUserStream,
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
                                        horizontal: 8,
                                        vertical: 4,
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                            if (currentUser != null &&
                                currentUser!.uid != widget.post.userId)
                              const SizedBox(width: 6),

                            if (currentUser == null ||
                                currentUser!.uid != widget.post.userId)
                              SizedBox(
                                width: 32,
                                height: 28,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  iconSize: 20,
                                  splashRadius: 16,
                                  onSelected: (value) async {
                                    if (value == 'report') {
                                      await ReportService.reportPost(
                                        postId: widget.post.id,
                                        userId: currentUser!.uid,
                                        reason: 'Inappropriate Content',
                                      );

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            _buildMoodCategoryRow(),

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

            if (widget.post.taggedUserIds.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'People in this moment',
                  style: TextStyle(
                    color: Color(0xFF7A7284),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TaggedPeopleSection(
                userIds: widget.post.taggedUserIds,
                compact: true,
              ),
            ],

            const SizedBox(height: 13),

            /// IMAGE or VIDEO (POST)
            /// IMAGE POST
            if (imageUrls.isNotEmpty && !isVideo)
              GestureDetector(
                onDoubleTap: () {
                  PostService.toggleLike(widget.post.id);
                },

                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    child: _PostImageGallery(
                      imageUrls: imageUrls,
                      mediaCountBadge: imageUrls.length > 1
                          ? _buildMediaCountBadge(
                              icon: Icons.photo_library_rounded,
                              count: imageUrls.length,
                            )
                          : null,
                    ),
                  ),
                ),
              )
            else if (isVideo)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.post.videoUrl.isNotEmpty ? _openVideoPost : null,
                onDoubleTap: () {
                  PostService.toggleLike(widget.post.id);
                },
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),

                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildVideoThumbnail(),
                        Center(child: _buildPlayOverlay()),
                        if (_videoController != null &&
                            _videoController!.value.isInitialized)
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: _buildVideoDurationBadge(
                              _videoController!.value.duration,
                            ),
                          ),
                      ],
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

class _PostImageGallery extends StatelessWidget {
  final List<String> imageUrls;
  final Widget? mediaCountBadge;

  const _PostImageGallery({required this.imageUrls, this.mediaCountBadge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: imageUrls[index],
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
            );
          },
        ),
        if (mediaCountBadge != null)
          Positioned(
            top: 12,
            right: 12,
            child: mediaCountBadge!,
          ),
      ],
    );
  }
}

class _FeedTimestamp extends StatefulWidget {
  final Timestamp createdAt;

  const _FeedTimestamp({required this.createdAt});

  @override
  State<_FeedTimestamp> createState() => _FeedTimestampState();
}

class _FeedTimestampState extends State<_FeedTimestamp> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      TimeAgoHelper.format(widget.createdAt),
      style: const TextStyle(
        color: Color(0xFF7A7284),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
