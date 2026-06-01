import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String imageUrl;
  final String videoUrl;
  final String type;
  final String text;
  final List<String> likedBy;
  final List comments;
  final DateTime createdAt;
  final String userId;
  final String content;
  final String username;
  final String userPhoto;

  Post({
    required this.id,
    required this.imageUrl,
    required this.videoUrl,
    required this.type,
    required this.text,
    required this.likedBy,
    required this.comments,
    required this.createdAt,
    required this.userId,
    required this.content,
    required this.username,
    required this.userPhoto,
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Post(
      id: doc.id,
      imageUrl: data['imageUrl'],
      videoUrl: data['videoUrl'],
      type: data['type'],
      text: data['text'],
      likedBy: List<String>.from(doc['likes'] ?? []),
      comments: List.from(doc['comments'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      username: data['username'] ?? 'user',
      userPhoto: data['userPhoto'] ?? '',
    );
  }
}
