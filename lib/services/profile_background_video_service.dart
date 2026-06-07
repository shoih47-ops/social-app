import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'cloudinary_service.dart';

/// Handles profile background video: load, preview, upload, and Firestore persistence.
class ProfileBackgroundVideoService {
  VideoPlayerController? controller;
  String backgroundVideoUrl = '';
  bool isUploading = false;

  VoidCallback? _onVideoUpdated;

  bool get hasVideo =>
      backgroundVideoUrl.isNotEmpty &&
      controller != null &&
      controller!.value.isInitialized;

  /// Reads [backgroundVideo] from a user document (exact Firestore field name).
  static String readVideoUrlFromData(Map<String, dynamic> data) {
    final backgroundVideo = data['backgroundVideo'];
    if (backgroundVideo != null) {
      final url = backgroundVideo.toString().trim();
      if (url.isNotEmpty) return url;
    }

    final coverType = data['coverType']?.toString();
    final coverUrl = data['coverUrl'];
    if (coverType == 'video' && coverUrl != null) {
      final url = coverUrl.toString().trim();
      if (url.isNotEmpty) return url;
    }

    return '';
  }

  Future<void> loadSavedVideo(
    String userId, {
    VoidCallback? onVideoUpdated,
  }) async {
    _onVideoUpdated = onVideoUpdated;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!doc.exists) {
      await _reset();
      _onVideoUpdated?.call();
      return;
    }

    final rawData = doc.data();
    if (rawData == null) {
      await _reset();
      _onVideoUpdated?.call();
      return;
    }

    await loadFromUserData(rawData);
  }

  /// Loads and plays background video from an already-fetched user document.
  Future<void> loadFromUserData(Map<String, dynamic> data) async {
    final savedUrl = readVideoUrlFromData(data);
    if (savedUrl.isEmpty) {
      await _reset();
      _onVideoUpdated?.call();
      return;
    }

    backgroundVideoUrl = savedUrl;

    try {
      await _playNetworkVideo(savedUrl);
    } catch (e) {
      debugPrint('Profile background video load failed: $e');
      await _disposeController();
      _onVideoUpdated?.call();
    }
  }

  Future<void> pickPreviewAndSave({
    required void Function() onStateChanged,
    void Function(String message)? onError,
    void Function(String message)? onSuccess,
  }) async {
    if (isUploading) return;

    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      isUploading = true;
      onStateChanged();

      await _playLocalVideo(file);
      onStateChanged();

      final uploadedUrl = await CloudinaryService.uploadVideo(file);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'backgroundVideo': uploadedUrl,
        'coverType': 'video',
        'coverUrl': uploadedUrl,
      }, SetOptions(merge: true));

      backgroundVideoUrl = uploadedUrl;
      await _playNetworkVideo(uploadedUrl);

      onSuccess?.call('Background video saved');
    } catch (e) {
      onError?.call('Failed to save background video');
    } finally {
      isUploading = false;
      onStateChanged();
    }
  }

  Future<void> _playLocalVideo(File file) async {
    await _disposeController();
    final localController = VideoPlayerController.file(file);
    controller = localController;
    _attachControllerListener(localController);
    await localController.initialize();
    localController
      ..setLooping(true)
      ..setVolume(1.0)
      ..play();
    _onVideoUpdated?.call();
  }

  Future<void> _playNetworkVideo(String url) async {
    await _disposeController();
    final networkController = VideoPlayerController.networkUrl(Uri.parse(url));
    controller = networkController;
    _attachControllerListener(networkController);
    await networkController.initialize();
    networkController
      ..setLooping(true)
      ..setVolume(1.0)
      ..play();
    _onVideoUpdated?.call();
  }

  void _attachControllerListener(VideoPlayerController videoController) {
    videoController.addListener(_handleControllerUpdate);
  }

  void _detachControllerListener(VideoPlayerController? videoController) {
    videoController?.removeListener(_handleControllerUpdate);
  }

  void _handleControllerUpdate() {
    if (controller?.value.isInitialized ?? false) {
      _onVideoUpdated?.call();
    }
  }

  Future<void> _reset() async {
    backgroundVideoUrl = '';
    await _disposeController();
  }

  Future<void> _disposeController() async {
    final old = controller;
    controller = null;
    _detachControllerListener(old);
    await old?.dispose();
  }

  void dispose() {
    _detachControllerListener(controller);
    controller?.dispose();
    controller = null;
    backgroundVideoUrl = '';
    _onVideoUpdated = null;
  }
}
