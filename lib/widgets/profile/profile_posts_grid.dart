import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../screens/my_moments_archive_screen.dart';
import '../../services/post_navigation_service.dart';

class ProfilePostsGrid extends StatelessWidget {
  const ProfilePostsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Life Story',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyMomentsArchiveScreen(
                        userId: currentUserId,
                      ),
                    ),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', isEqualTo: currentUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final posts = snapshot.data!.docs;

            final chronologicalPosts = posts.where(_hasCreatedAt).toList()
              ..sort((a, b) {
                final aDate = _createdAt(a)!;
                final bDate = _createdAt(b)!;
                return bDate.compareTo(aDate);
              });

            if (chronologicalPosts.isEmpty) {
              return const _LifeStoryEmptyState();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.white,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < chronologicalPosts.length;
                      index++
                    )
                      _LifeStoryPreviewItem(
                        post: chronologicalPosts[index].data(),
                        showDivider: index < chronologicalPosts.length - 1,
                        onTap: () {
                          final doc = chronologicalPosts[index];
                          PostNavigationService.openPostFromSnapshot(
                            context,
                            postDoc: doc,
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static bool _hasCreatedAt(QueryDocumentSnapshot post) {
    return _createdAt(post) != null;
  }

  static DateTime? _createdAt(QueryDocumentSnapshot post) {
    final data = post.data() as Map<String, dynamic>;
    final value = data['createdAt'];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
  }
}

class _LifeStoryPreviewItem extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool showDivider;
  final VoidCallback onTap;

  const _LifeStoryPreviewItem({
    required this.post,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = (post['type'] ?? 'image').toString();
    final imageUrl = post['imageUrl'] as String?;
    final hasThumbnail = imageUrl != null && imageUrl.isNotEmpty;
    final isVideo = type == 'video';
    final text = (post['text'] ?? '').toString().trim();
    final displayText = text.isNotEmpty ? text : _fallbackLabel(type);
    final createdAtText = _formatCreatedAt(post['createdAt']);

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (createdAtText != null) ...[
                        Text(
                          createdAtText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        displayText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasThumbnail || isVideo) ...[
                  const SizedBox(width: 14),
                  _LifeStoryThumbnail(
                    imageUrl: imageUrl,
                    isVideo: isVideo,
                  ),
                ],
              ],
            ),
          ),
          if (showDivider)
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFEDEDF2),
            ),
        ],
      ),
    );
  }

  String _fallbackLabel(String type) {
    if (type == 'video') return '🎥 Video';
    if (type == 'text') return '📝 Text Post';
    return '📷 Photo';
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

    return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year}';
  }
}

class _LifeStoryThumbnail extends StatelessWidget {
  final String? imageUrl;
  final bool isVideo;

  const _LifeStoryThumbnail({required this.imageUrl, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const ColoredBox(color: Colors.black12),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: Colors.black12),
              )
            else
              const ColoredBox(color: Colors.black87),
            if (isVideo)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.22),
                child: const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 26,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LifeStoryEmptyState extends StatelessWidget {
  const _LifeStoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          child: Center(
            child: Text(
              'Your life story starts with your first post',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
