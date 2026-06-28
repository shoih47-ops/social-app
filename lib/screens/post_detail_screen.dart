import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_app/screens/image_view_screen.dart';
import 'package:social_app/utils/time_ago.dart';
import 'package:social_app/widgets/comments_list_view.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';

import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../services/share_service.dart';

import '../widgets/like_button.dart';
import '../widgets/comment_button.dart';
import '../widgets/tagged_people_section.dart';

import '../models/post.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController commentController = TextEditingController();
  Timer? _timeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timeRefreshTimer?.cancel();
    commentController.dispose();
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

  Widget _buildMoodCategoryChips(Post post) {
    final chips = <Widget>[
      if (post.mood.trim().isNotEmpty) _buildMetaChip(post.mood.trim()),
      if (post.category.trim().isNotEmpty) _buildMetaChip(post.category.trim()),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 3),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Future<void> addComment(Map<String, dynamic> data) async {
    if (commentController.text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final userData = userDoc.data() as Map<String, dynamic>;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
          "userId": user.uid,
          "username": userData['username'],
          "photoUrl": userData['photoUrl'],
          "text": commentController.text,
          "createdAt": FieldValue.serverTimestamp(),
          "likes": [],
        });

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({'commentCount': FieldValue.increment(1)});

    final username = userDoc.data()?['username'] ?? 'Someone';

    await sendNotification(
      toUserId: data['userId'],
      type: "comment",
      fromUserId: user.uid,
      fromUsername: username,
      postId: widget.postId,
    );

    commentController.clear();
  }

  Widget _buildCommentInput(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => addComment(data),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final post = Post(
            id: widget.postId,
            text: data['text'] ?? '',
            imageUrl: data['imageUrl'] ?? '',
            imageUrls: List<String>.from(data['imageUrls'] ?? []),
            videoUrl: data['videoUrl'] ?? '',
            type: data['type'] ?? 'image',
            likedBy: List<String>.from(data['likes'] ?? []),
            comments: [],
            createdAt: TimeAgoHelper.fromFirestore(data['createdAt']),
            userId: data['userId'] ?? '',
            content: data['content'] ?? '',
            username: data['username'] ?? '',
            userPhoto: data['userPhoto'] ?? '',
            mood: data['mood'] ?? '',
            category: data['category'] ?? '',
            taggedUserIds: List<String>.from(data['taggedUserIds'] ?? []),
          );

          final imageUrls = post.effectiveImageUrls;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(post.userId)
                              .snapshots(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData ||
                                userSnapshot.data?.data() == null) {
                              return const SizedBox();
                            }

                            final userData =
                                userSnapshot.data?.data()
                                    as Map<String, dynamic>;

                            final currentUid =
                                FirebaseAuth.instance.currentUser!.uid;

                            final isOwner = post.userId == currentUid;

                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (isOwner) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ProfileScreen(userId: currentUid),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserProfileScreen(
                                            userId: post.userId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: const Color(
                                          0xfff3e8ff,
                                        ),
                                        backgroundImage:
                                            userData['photoUrl'] != null &&
                                                userData['photoUrl']
                                                    .toString()
                                                    .isNotEmpty
                                            ? NetworkImage(userData['photoUrl'])
                                            : null,
                                        child:
                                            userData['photoUrl'] == null ||
                                                userData['photoUrl']
                                                    .toString()
                                                    .isEmpty
                                            ? const Icon(
                                                Icons.person,
                                                color: Color(0xff8b5cf6),
                                                size: 20,
                                              )
                                            : null,
                                      ),

                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userData['username'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 2),

                                          _buildMoodCategoryChips(post),

                                          Text(
                                            TimeAgoHelper.format(
                                              post.createdAt,
                                              display: TimeAgoDisplay.detail,
                                            ),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                if (isOwner)
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Post'),
                                            content: const Text(
                                              'Are you sure you want to delete this post?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          print('DELETE ID: ${widget.postId}');
                                          if (mounted) Navigator.pop(context);
                                          await PostService.deletePost(
                                            widget.postId,
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete Post'),
                                      ),
                                    ],
                                  ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        if ((data['text'] ?? '').isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 32),
                            child: Text(
                              data['text'] ?? '',
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],

                        TaggedPeopleSection(userIds: post.taggedUserIds),

                        if (post.taggedUserIds.isNotEmpty)
                          const SizedBox(height: 12),

                        if (imageUrls.isNotEmpty)
                          _PostDetailImageGallery(imageUrls: imageUrls),

                        const SizedBox(height: 10),

                        // Videos are viewed in fullscreen; don't embed here.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            LikeButton(post: post),

                            const SizedBox(width: 24),

                            CommentButton(
                              postId: widget.postId,
                              postOwnerId: data['userId'],
                            ),

                            const SizedBox(width: 24),

                            IconButton(
                              tooltip: 'Share',
                              onPressed: () {
                                ShareService.showShareOptions(context, post);
                              },
                              icon: const Icon(Icons.ios_share_outlined),
                              color: const Color(0xFF5B21B6),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        CommentsListView(
                          postId: widget.postId,
                          postOwnerId: post.userId,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          commentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 6,
                          ),
                        ),

                      ],
                    ),
                  ),
                  _buildCommentInput(data),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PostDetailImageGallery extends StatefulWidget {
  final List<String> imageUrls;

  const _PostDetailImageGallery({required this.imageUrls});

  @override
  State<_PostDetailImageGallery> createState() =>
      _PostDetailImageGalleryState();
}

class _PostDetailImageGalleryState extends State<_PostDetailImageGallery> {
  int _page = 0;
  final Map<String, double> _aspectRatios = {};
  final Set<String> _resolvingUrls = {};

  @override
  void didUpdateWidget(covariant _PostDetailImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls != widget.imageUrls) {
      _page = 0;
      _aspectRatios.removeWhere((url, _) => !widget.imageUrls.contains(url));
      _resolvingUrls.removeWhere((url) => !widget.imageUrls.contains(url));
    }
  }

  void _resolveAspectRatio(BuildContext context, String imageUrl) {
    if (_aspectRatios.containsKey(imageUrl) ||
        _resolvingUrls.contains(imageUrl)) {
      return;
    }

    _resolvingUrls.add(imageUrl);
    final provider = NetworkImage(imageUrl);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, _) {
        final image = imageInfo.image;
        final aspectRatio = image.width / image.height;
        stream.removeListener(listener);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _resolvingUrls.remove(imageUrl);
            _aspectRatios[imageUrl] = aspectRatio;
          });
        });
      },
      onError: (_, _) {
        stream.removeListener(listener);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _resolvingUrls.remove(imageUrl);
          });
        });
      },
    );
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final currentImageUrl = widget.imageUrls[_page];
    _resolveAspectRatio(context, currentImageUrl);
    final aspectRatio = _aspectRatios[currentImageUrl] ?? 1;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.68;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth,
              maxHeight: maxHeight,
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      itemCount: widget.imageUrls.length,
                      onPageChanged: (page) {
                        setState(() {
                          _page = page;
                        });
                      },
                      itemBuilder: (context, index) {
                        final imageUrl = widget.imageUrls[index];
                        _resolveAspectRatio(context, imageUrl);

                        return InteractiveViewer(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ImageViewScreen(imageUrl: imageUrl),
                                ),
                              );
                            },
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                    if (widget.imageUrls.length > 1)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.56),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_page + 1}/${widget.imageUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
