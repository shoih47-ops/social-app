import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../screens/create_post_screen.dart';
import '../../services/post_navigation_service.dart';
import '../../services/post_service.dart';

class UserProfilePostsGrid extends StatelessWidget {
  final String userId;

  const UserProfilePostsGrid({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == userId;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Moments",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final posts = snapshot.data!.docs;

            return ValueListenableBuilder<Set<String>>(
              valueListenable: PostService.deletingVideoPostIds,
              builder: (context, deletingVideoPostIds, _) {
                final visiblePosts = posts.where((doc) {
                  final post = doc.data() as Map<String, dynamic>;
                  final type = post['type'] ?? 'image';
                  return type != 'video' ||
                      !deletingVideoPostIds.contains(doc.id);
                }).toList();

                if (visiblePosts.isEmpty) {
                  return _MomentsEmptyState(isCurrentUser: isCurrentUser);
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  itemCount: visiblePosts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final doc = visiblePosts[index];
                    final post = doc.data() as Map<String, dynamic>;
                    final type = post['type'] ?? 'image';

                    return GestureDetector(
                      onTap: () {
                        PostNavigationService.openPostFromSnapshot(
                          context,
                          postDoc: doc,
                        );
                      },
                      child: _PostGridThumbnail(
                        postId: doc.id,
                        post: post,
                        isVideo: type == 'video',
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _MomentsEmptyState extends StatelessWidget {
  final bool isCurrentUser;

  const _MomentsEmptyState({required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCurrentUser
                  ? 'Share your first life moment ✨'
                  : 'No moments yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCurrentUser
                  ? 'Create your first post'
                  : "This user hasn't shared any moments yet.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D4CFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Create your first post',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostGridThumbnail extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> post;
  final bool isVideo;

  const _PostGridThumbnail({
    required this.postId,
    required this.post,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = post['imageUrl'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final createdAtText = _formatCreatedAt(post['createdAt']);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage && !isVideo)
            Hero(
              tag: postId,
              flightShuttleBuilder:
                  (
                    flightContext,
                    animation,
                    flightDirection,
                    fromHeroContext,
                    toHeroContext,
                  ) {
                    return FadeTransition(
                      opacity: animation.drive(
                        CurveTween(curve: Curves.easeInOut),
                      ),
                      child: toHeroContext.widget,
                    );
                  },
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const ColoredBox(color: Colors.black12),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: Colors.black12),
              ),
            )
          else if (hasImage)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const ColoredBox(color: Colors.black12),
              errorWidget: (context, url, error) =>
                  const ColoredBox(color: Colors.black12),
            )
          else if (isVideo)
            const ColoredBox(color: Colors.black)
          else
            ColoredBox(
              color: const Color(0xFFF2F2F2),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    post['text'] ?? '',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          if (isVideo)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white70,
                size: 30,
              ),
            ),
          if (createdAtText != null)
            Positioned(
              left: 6,
              bottom: 6,
              child: _CreatedAtBadge(
                text: createdAtText,
                isMedia: hasImage || isVideo,
              ),
            ),
        ],
      ),
    );
  }

  String? _formatCreatedAt(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return null;

    final localDate = date.toLocal();
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
    final hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final minute = localDate.minute.toString().padLeft(2, '0');
    final period = localDate.hour >= 12 ? 'PM' : 'AM';

    return '${months[localDate.month - 1]} ${localDate.day} • $hour:$minute $period';
  }
}

class _CreatedAtBadge extends StatelessWidget {
  final String text;
  final bool isMedia;

  const _CreatedAtBadge({required this.text, required this.isMedia});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isMedia
            ? Colors.black.withValues(alpha: 0.58)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMedia ? Colors.white : Colors.black87,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
