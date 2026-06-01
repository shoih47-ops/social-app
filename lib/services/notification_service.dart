import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> sendNotification({
  required String toUserId,
  required String type,
  required String fromUserId,
  required String fromUsername,
  String? postId,
}) async {
  try {
    if (toUserId == fromUserId) return;

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
          'createdAt': Timestamp.now(),
          'isRead': false,
        });

    print("✔️ notification send");
  } catch (e) {
    print("✖️ ERROR: $e");
  }
}
