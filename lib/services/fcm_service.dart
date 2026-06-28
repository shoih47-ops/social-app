import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'post_navigation_service.dart';

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_openNotification);
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openNotification(initialMessage),
      );
    }
  }

  void attachNavigator(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  Future<void> syncTokenForCurrentUser() async {
    await initialize();
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    await _saveToken(token);
  }

  Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token == null || token.isEmpty) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> _openNotification(RemoteMessage message) async {
    final data = message.data;
    final notificationType =
        (data['notificationType'] ?? data['type'] ?? '').toString();
    final postId = (data['postId'] ?? '').toString().trim();

    if (notificationType == 'follow' || postId.isEmpty) return;

    final receiverId =
        (data['receiverId'] ?? data['toUserId'] ?? '').toString();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null ||
        (receiverId.isNotEmpty && receiverId != currentUser.uid)) {
      return;
    }

    // AuthGate may still be building after a terminated-app notification tap.
    for (var attempt = 0; attempt < 20; attempt++) {
      final context = _navigatorKey?.currentContext;
      if (context != null && context.mounted) {
        await PostNavigationService.openPost(
          context,
          postId: postId,
          openComments:
              notificationType == 'comment' || notificationType == 'reply',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('Could not open FCM notification: navigator is not ready');
  }
}
