import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_app/services/post_service.dart';
import 'package:video_player/video_player.dart';
import 'package:shimmer/shimmer.dart';

import '../models/post.dart';
import '../screens/post_video_fullscreen_page.dart';
import '../utils/time_ago.dart';
import 'like_button.dart';
import 'comment_button.dart';
import '../screens/user_profile_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../services/follow_service.dart';
import '../services/report_service.dart';

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

  Widget _buildMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF6D28D9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMoodCategoryChips() {
    final chips = <Widget>[
      if (widget.post.mood.trim().isNotEmpty)
        _buildMetaChip(widget.post.mood.trim()),
      if (widget.post.category.trim().isNotEmpty)
        _buildMetaChip(widget.post.category.trim()),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("TYPE: ${widget.post.type}");
    print("IMAGE URL: ${widget.post.imageUrl}");

    return GestureDetector(
      onTap: () {
        if (widget.post.type == 'video' && widget.post.videoUrl.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostVideoFullscreenPage(post: widget.post),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: widget.post.id),
            ),
          );
        }
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFE),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
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
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                TimeAgoHelper.format(
                                  widget.post.createdAt,
                                  display: TimeAgoDisplay.feed,
                                ),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              _buildMoodCategoryChips(),
                            ],
                          ),
                        ),

                        const SizedBox(width: 18),

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
                                    horizontal: 14,
                                    vertical: 7,
                                  ),

                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),

                                  child: Text(
                                    isFollowing ? "Following" : "Follow",

                                    style: const TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(width: 14),

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

            const SizedBox(height: 12),

            // Text Post
            if (widget.post.text.isNotEmpty)
              Text(
                widget.post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black,
                ),
              ),

            const SizedBox(height: 14),

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
                              child: VideoPlayer(_videoController!),
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

            const SizedBox(height: 16),

            /// ACTIONS
            Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
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
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
