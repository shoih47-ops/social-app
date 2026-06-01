import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../screens/post_detail_screen.dart';
import '../../models/post.dart';
import '../../screens/post_video_fullscreen_page.dart';

class UserProfilePostsGrid extends StatelessWidget {
  final String userId;

  const UserProfilePostsGrid({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Posts",
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

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              itemCount: posts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final doc = posts[index];
                final post = doc.data() as Map<String, dynamic>;

                final type = post['type'] ?? 'image';

                return GestureDetector(
                  onTap: () {
                    if (type == 'video') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostVideoFullscreenPage(
                            post: Post.fromDocument(doc),
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(postId: doc.id),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: type == 'video'
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child:
                                (post['imageUrl'] != null &&
                                    post['imageUrl'] != "")
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: post['imageUrl'],
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                      const Center(
                                        child: Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.white70,
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  )
                                : Stack(
                                    fit: StackFit.expand,
                                    children: const [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                        ),
                                      ),
                                      Center(
                                        child: Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.white70,
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                          )
                        : (post['imageUrl'] != null && post['imageUrl'] != ""
                              ? Hero(
                                  tag: doc.id,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: CachedNetworkImage(
                                      imageUrl: post['imageUrl'],
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      post['text'] ?? '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
