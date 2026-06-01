import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'profile_background.dart';

/// Shared profile body: background + scroll content (+ optional cover actions).
/// Used by [ProfileScreen] and [UserProfileScreen] so video layout stays identical.
class ProfileScreenLayout extends StatelessWidget {
  final String coverType;
  final String coverUrl;
  final String backgroundVideoUrl;
  final VideoPlayerController? videoController;
  final bool isUploading;
  final Widget content;
  final Widget? coverActions;

  const ProfileScreenLayout({
    super.key,
    required this.coverType,
    required this.coverUrl,
    required this.backgroundVideoUrl,
    required this.videoController,
    this.isUploading = false,
    required this.content,
    this.coverActions,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ProfileBackground(
          coverType: coverType,
          coverUrl: coverUrl,
          backgroundVideoUrl: backgroundVideoUrl,
          controller: videoController,
          isUploading: isUploading,
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 150),
                content,
              ],
            ),
          ),
        ),
        if (coverActions != null) coverActions!,
      ],
    );
  }
}
