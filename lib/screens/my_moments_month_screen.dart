import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/post_navigation_service.dart';
import '../services/post_service.dart';

class MyMomentsMonthScreen extends StatelessWidget {
  final String userId;
  final int year;
  final int month;
  final String monthName;

  const MyMomentsMonthScreen({
    super.key,
    required this.userId,
    required this.year,
    required this.month,
    required this.monthName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text('$monthName $year'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs.where((doc) {
            final date = _createdAt(doc)?.toLocal();
            return date != null && date.year == year && date.month == month;
          }).toList()
            ..sort((a, b) {
              final aDate = _createdAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = _createdAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

          return ValueListenableBuilder<Set<String>>(
            valueListenable: PostService.deletingVideoPostIds,
            builder: (context, deletingVideoPostIds, _) {
              final visiblePosts = posts.where((doc) {
                final post = doc.data() as Map<String, dynamic>;
                final type = post['type'] ?? 'image';
                return type != 'video' || !deletingVideoPostIds.contains(doc.id);
              }).toList();

              if (visiblePosts.isEmpty) {
                return const Center(
                  child: Text(
                    'No moments in this month',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                itemCount: visiblePosts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
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
    );
  }

  static DateTime? _createdAt(QueryDocumentSnapshot post) {
    final data = post.data() as Map<String, dynamic>;
    final value = data['createdAt'];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
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
                    maxLines: 7,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
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
        ],
      ),
    );
  }
}
