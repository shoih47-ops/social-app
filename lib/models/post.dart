import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String imageUrl;
  final List<String> imageUrls;
  final String videoUrl;
  final String type;
  final String text;
  final List<String> likedBy;
  final List comments;
  final Timestamp createdAt;
  final String userId;
  final String content;
  final String username;
  final String userPhoto;
  final String mood;
  final String category;
  final List<String> taggedUserIds;

  Post({
    required this.id,
    required this.imageUrl,
    this.imageUrls = const [],
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
    this.mood = '',
    this.category = '',
    this.taggedUserIds = const [],
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final imageUrl = data['imageUrl'] ?? '';
    final imageUrls = List<String>.from(data['imageUrls'] ?? const []);

    return Post(
      id: doc.id,
      imageUrl: imageUrl,
      imageUrls: imageUrls.isEmpty && imageUrl.isNotEmpty
          ? [imageUrl]
          : imageUrls,
      videoUrl: data['videoUrl'],
      type: data['type'],
      text: data['text'],
      likedBy: List<String>.from(doc['likes'] ?? []),
      comments: List.from(doc['comments'] ?? []),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.fromDate(DateTime.now()),
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      username: data['username'] ?? 'user',
      userPhoto: data['userPhoto'] ?? '',
      mood: data['mood'] ?? '',
      category: data['category'] ?? '',
      taggedUserIds: List<String>.from(data['taggedUserIds'] ?? []),
    );
  }

  List<String> get effectiveImageUrls {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl.isNotEmpty) return [imageUrl];
    return const [];
  }
}
