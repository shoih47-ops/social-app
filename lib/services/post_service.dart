import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> toggleLike(String postId) async {
    final user = FirebaseAuth.instance.currentUser;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    final doc = await postRef.get();
    final data = doc.data();

    List likes = data?['like'] ?? [];

    if (likes.contains(user!.uid)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([user.uid]),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([user.uid]),
      });
    }
  }

  /// Adds a post. Provide either [imageUrl] or [videoUrl] and set [type]
  /// to 'image' or 'video'. Keeps existing image posts working.
  static Future<void> addPost({
    required String text,
    String imageUrl = '',
    String videoUrl = '',
    required String type,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userDoc = await _db.collection('users').doc(user!.uid).get();
    final userData = userDoc.data();

    await _db.collection('posts').add({
      'text': text,
      'comments': [],
      'createdAt': Timestamp.now(),
      'userId': user.uid,
      'username': userData?['username'] ?? user.displayName ?? '',
      'userPhoto': userData?['photoUrl'] ?? '',
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'type': type,
      'likes': [],
    });
  }

  static Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }
}
