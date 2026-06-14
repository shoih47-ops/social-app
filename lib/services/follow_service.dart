import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future followUser(String myId, String userId, String myUsername) async {
    await _firestore.collection('users').doc(userId).update({
      'followers': FieldValue.arrayUnion([myId]),
    });

    await _firestore.collection('users').doc(myId).update({
      'following': FieldValue.arrayUnion([userId]),
    });

    await _firestore
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
          'toUserId': userId,
          'type': 'follow',
          'fromUserId': myId,
          'fromUsername': myUsername,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
  }

  Future sendNotification({
    required String toUserId,
    required String type,
    required String fromUserId,
    required String fromUsername,
  }) async {
    await _firestore.collection('notifications').add({
      'toUserId': toUserId,
      'type': type,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future unfollowUser(String myId, String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'followers': FieldValue.arrayRemove([myId]),
    });

    await _firestore.collection('users').doc(myId).update({
      'following': FieldValue.arrayRemove([userId]),
    });
  }

  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    List following = doc['following'] ?? [];

    return following.contains(targetUserId);
  }
}
