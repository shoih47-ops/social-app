import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  static Future<void> reportPost({
    required String postId,
    required String userId,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'postId': postId,
      'reportedBy': userId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
