import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/post_navigation_service.dart';
import '../services/post_service.dart';

class FeaturedPersonMomentsScreen extends StatelessWidget {
  final String profileUserId;
  final String featuredUserId;
  final String featuredUserName;

  const FeaturedPersonMomentsScreen({
    super.key,
    required this.profileUserId,
    required this.featuredUserId,
    required this.featuredUserName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text('Moments with $featuredUserName'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: profileUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs.where((document) {
            return _taggedUserIds(
              document.data()['taggedUserIds'],
            ).contains(featuredUserId);
          }).toList()
            ..sort((first, second) {
              return _createdAt(second).compareTo(_createdAt(first));
            });

          return ValueListenableBuilder<Set<String>>(
            valueListenable: PostService.deletingVideoPostIds,
            builder: (context, deletingVideoPostIds, _) {
              final visiblePosts = posts.where((document) {
                final type = document.data()['type'] ?? 'image';
                return type != 'video' ||
                    !deletingVideoPostIds.contains(document.id);
              }).toList();

              if (visiblePosts.isEmpty) {
                return const Center(
                  child: Text(
                    'No moments found',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: visiblePosts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final document = visiblePosts[index];
                  final post = document.data();
                  return GestureDetector(
                    onTap: () {
                      PostNavigationService.openPostFromSnapshot(
                        context,
                        postDoc: document,
                      );
                    },
                    child: _FeaturedMomentThumbnail(
                      post: post,
                      isVideo: post['type'] == 'video',
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

  static List<String> _taggedUserIds(dynamic value) {
    if (value is! List) return const [];
    return value.map((id) => id.toString()).toList();
  }

  static DateTime _createdAt(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final value = document.data()['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _FeaturedMomentThumbnail extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isVideo;

  const _FeaturedMomentThumbnail({required this.post, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
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
                    (post['text'] ?? '').toString(),
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
        ],
      ),
    );
  }
}
