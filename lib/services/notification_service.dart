import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> sendNotification({
  required String toUserId,
  required String type,
  required String fromUserId,
  required String fromUsername,
  String? postId,
  String? postType,
}) async {
  try {
    if (toUserId == fromUserId) return;

    var resolvedPostType = postType ?? '';
    if (resolvedPostType.isEmpty && postId != null && postId.isNotEmpty) {
      final post = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      resolvedPostType = (post.data()?['type'] ?? '').toString();
    }

    print("🔥 sending notification...");

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(toUserId)
        .collection('items')
        .add({
          'type': type,
          'fromUserId': fromUserId,
          'fromUsername': fromUsername,
          'postId': postId,
          'postType': resolvedPostType,
          'senderId': fromUserId,
          'receiverId': toUserId,
          'notificationType': type,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });

    print("✔️ notification send");
  } catch (e) {
    print("✖️ ERROR: $e");
  }
}
