import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../screens/create_post_screen.dart';
import '../../services/post_navigation_service.dart';
import '../../services/post_service.dart';

class UserProfileMomentsTabs extends StatefulWidget {
  final String userId;

  const UserProfileMomentsTabs({super.key, required this.userId});

  @override
  State<UserProfileMomentsTabs> createState() => _UserProfileMomentsTabsState();
}

class _UserProfileMomentsTabsState extends State<UserProfileMomentsTabs> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _ProfileMomentTab(
                  label: 'Moments',
                  isSelected: _selectedIndex == 0,
                  onTap: () => _selectTab(0),
                ),
              ),
              Expanded(
                child: _ProfileMomentTab(
                  label: 'Tagged',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _selectTab(1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Offstage(
          offstage: _selectedIndex != 0,
          child: UserProfilePostsGrid(
            userId: widget.userId,
            showTitle: false,
          ),
        ),
        Offstage(
          offstage: _selectedIndex != 1,
          child: UserProfileTaggedMomentsGrid(
            userId: widget.userId,
            showTitle: false,
          ),
        ),
      ],
    );
  }
}

class _ProfileMomentTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileMomentTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF6D4CFF) : Colors.black12,
              width: isSelected ? 2.5 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6D4CFF) : Colors.black54,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class UserProfilePostsGrid extends StatelessWidget {
  final String userId;
  final bool showTitle;

  const UserProfilePostsGrid({
    super.key,
    required this.userId,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = FirebaseAuth.instance.currentUser?.uid == userId;

    return Column(
      children: [
        if (showTitle) ...[
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
        ],

        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _ownedPostsStream(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final posts = snapshot.data!;

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

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _ownedPostsStream(
    String profileUserId,
  ) {
    late final StreamController<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>> controller;
    final sourceDocs =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emitPosts() {
      final postsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      for (final docs in sourceDocs.values) {
        for (final doc in docs) {
          if (_isOwnedByProfileUser(doc.data(), profileUserId)) {
            postsById[doc.id] = doc;
          }
        }
      }

      final posts = postsById.values.toList()
        ..sort((first, second) {
          final secondDate = _createdAt(second.data());
          final firstDate = _createdAt(first.data());
          return secondDate.compareTo(firstDate);
        });

      if (!controller.isClosed) controller.add(posts);
    }

    void listenToSource(String key, Query<Map<String, dynamic>> query) {
      subscriptions.add(
        query.snapshots().listen(
          (snapshot) {
            sourceDocs[key] = snapshot.docs;
            emitPosts();
          },
          onError: controller.addError,
        ),
      );
    }

    controller = StreamController<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      onListen: () {
        final posts = FirebaseFirestore.instance.collection('posts');
        listenToSource(
          'ownerId',
          posts.where('ownerId', isEqualTo: profileUserId),
        );
        listenToSource(
          'userId',
          posts.where('userId', isEqualTo: profileUserId),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  bool _isOwnedByProfileUser(
    Map<String, dynamic> post,
    String profileUserId,
  ) {
    final ownerId = post['ownerId']?.toString().trim();
    final userId = post['userId']?.toString().trim();
    return ownerId == profileUserId || userId == profileUserId;
  }

  DateTime _createdAt(Map<String, dynamic> post) {
    final value = post['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class UserProfileTaggedMomentsGrid extends StatelessWidget {
  final String userId;
  final bool showTitle;

  const UserProfileTaggedMomentsGrid({
    super.key,
    required this.userId,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showTitle) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Tagged Moments",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _taggedPostsStream(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final posts = snapshot.data!;

            return ValueListenableBuilder<Set<String>>(
              valueListenable: PostService.deletingVideoPostIds,
              builder: (context, deletingVideoPostIds, _) {
                final visiblePosts = posts.where((doc) {
                  final post = doc.data();
                  final type = post['type'] ?? 'image';
                  return type != 'video' ||
                      !deletingVideoPostIds.contains(doc.id);
                }).toList();

                if (visiblePosts.isEmpty) {
                  return const _TaggedMomentsEmptyState();
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
                    final post = doc.data();
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
                        showOwnerBadge: true,
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

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _taggedPostsStream(
    String profileUserId,
  ) {
    late final StreamController<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>> controller;
    final sourceDocs =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emitPosts() {
      final postsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      for (final docs in sourceDocs.values) {
        for (final doc in docs) {
          final post = doc.data();
          if (_isTaggedWithProfileUser(post, profileUserId) &&
              !_isOwnedByProfileUser(post, profileUserId)) {
            postsById[doc.id] = doc;
          }
        }
      }

      final posts = postsById.values.toList()
        ..sort((first, second) {
          final secondDate = _createdAt(second.data());
          final firstDate = _createdAt(first.data());
          return secondDate.compareTo(firstDate);
        });

      if (!controller.isClosed) controller.add(posts);
    }

    void listenToSource(String key, Query<Map<String, dynamic>> query) {
      subscriptions.add(
        query.snapshots().listen(
          (snapshot) {
            sourceDocs[key] = snapshot.docs;
            emitPosts();
          },
          onError: controller.addError,
        ),
      );
    }

    controller = StreamController<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      onListen: () {
        final posts = FirebaseFirestore.instance.collection('posts');
        listenToSource(
          'taggedUserIds',
          posts.where('taggedUserIds', arrayContains: profileUserId),
        );
        listenToSource(
          'taggedUsers',
          posts.where('taggedUsers', arrayContains: profileUserId),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  bool _isTaggedWithProfileUser(
    Map<String, dynamic> post,
    String profileUserId,
  ) {
    final taggedUserIds = post['taggedUserIds'];
    final taggedUsers = post['taggedUsers'];

    return _containsUserId(taggedUserIds, profileUserId) ||
        _containsUserId(taggedUsers, profileUserId);
  }

  bool _isOwnedByProfileUser(
    Map<String, dynamic> post,
    String profileUserId,
  ) {
    final ownerId = post['ownerId']?.toString().trim();
    final userId = post['userId']?.toString().trim();
    return ownerId == profileUserId || userId == profileUserId;
  }

  bool _containsUserId(dynamic value, String profileUserId) {
    if (value is! List) return false;

    return value.map((id) => id.toString().trim()).contains(profileUserId);
  }

  DateTime _createdAt(Map<String, dynamic> post) {
    final value = post['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _TaggedMomentsEmptyState extends StatelessWidget {
  const _TaggedMomentsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Text(
          'No tagged moments yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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
  final bool showOwnerBadge;

  const _PostGridThumbnail({
    required this.postId,
    required this.post,
    required this.isVideo,
    this.showOwnerBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = post['imageUrl'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final createdAtText = _formatCreatedAt(post['createdAt']);
    final ownerName = _profileGridFirstText([
      post['username'],
      post['ownerName'],
    ]);
    final ownerPhotoUrl = _profileGridFirstText([
      post['userPhoto'],
      post['ownerPhotoUrl'],
      post['photoUrl'],
    ]);

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
          if (showOwnerBadge)
            Positioned(
              left: 6,
              top: 6,
              right: 6,
              child: _PostOwnerBadge(
                name: ownerName,
                photoUrl: ownerPhotoUrl,
                isMedia: hasImage || isVideo,
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

String _profileGridFirstText(List<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

class _PostOwnerBadge extends StatelessWidget {
  final String name;
  final String photoUrl;
  final bool isMedia;

  const _PostOwnerBadge({
    required this.name,
    required this.photoUrl,
    required this.isMedia,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 96),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMedia
                ? Colors.black.withValues(alpha: 0.48)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(2, 2, name.isEmpty ? 2 : 7, 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFFEDE9FE),
                  backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                  child: hasPhoto
                      ? null
                      : Icon(
                          Icons.person,
                          size: 12,
                          color: isMedia
                              ? const Color(0xFFD8C7FF)
                              : const Color(0xFF6D28D9),
                        ),
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMedia ? Colors.white : Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
