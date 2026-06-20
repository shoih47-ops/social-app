import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../screens/post_detail_screen.dart';
import '../screens/post_video_fullscreen_page.dart';

class PostNavigationService {
  static Future<void> openPost(
    BuildContext context, {
    required String postId,
    bool openComments = false,
  }) async {
    if (postId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post not found')));
      return;
    }

    final postDoc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .get();

    if (!context.mounted) return;

    if (!postDoc.exists || postDoc.data() == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post not found')));
      return;
    }

    final data = postDoc.data()!;
    if (data['type'] == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostVideoFullscreenPage(
            post: Post.fromDocument(postDoc),
            openComments: openComments,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
    );
  }

  static void openPostFromSnapshot(
    BuildContext context, {
    required DocumentSnapshot postDoc,
    bool openComments = false,
  }) {
    final data = postDoc.data();
    if (data is Map<String, dynamic> && data['type'] == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostVideoFullscreenPage(
            post: Post.fromDocument(postDoc),
            openComments: openComments,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postDoc.id)),
    );
  }
}
