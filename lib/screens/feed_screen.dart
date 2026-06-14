import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/post.dart';
import '../services/post_service.dart';
import '../utils/time_ago.dart';
import '../widgets/post_card.dart';

import 'create_post_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const SizedBox();
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),

      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            );
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: const Text(
              "How was your day?",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              );
            }

            final posts = snapshot.data!.docs;

            if (posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 70,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No posts yet",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Share your first real moment ✨",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                // Just wait for a moment to simulate refresh
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                physics: const BouncingScrollPhysics(),
                cacheExtent: 1000,
                itemCount: posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == posts.length) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: const Center(
                        child: Text("No more stories for now"),
                      ),
                    );
                  }

                  final data = posts[index].data() as Map<String, dynamic>;

                  final post = Post(
                    id: posts[index].id,
                    text: data['text'] ?? '',
                    imageUrl: data['imageUrl'] ?? '',
                    videoUrl: data['videoUrl'] ?? '',
                    type: data['type'] ?? '',
                    comments: List.from(data['comments'] ?? []),
                    likedBy: List<String>.from(data['likes'] ?? []),
                    createdAt: TimeAgoHelper.fromFirestore(data['createdAt']),
                    userId: data['userId'] ?? '',
                    content: data['content'] ?? '',
                    username: data['username'] ?? 'user',
                    userPhoto: data['photoUrl'] ?? '',
                    mood: data['mood'] ?? '',
                    category: data['category'] ?? '',
                  );

                  return ValueListenableBuilder<Set<String>>(
                    valueListenable: PostService.deletingVideoPostIds,
                    builder: (context, deletingVideoPostIds, _) {
                      if (post.type == 'video' &&
                          deletingVideoPostIds.contains(post.id)) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                        child:
                            PostCard(
                                  key: ValueKey(post.id),
                                  post: post,
                                  userData: data,
                                )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.05, end: 0),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
