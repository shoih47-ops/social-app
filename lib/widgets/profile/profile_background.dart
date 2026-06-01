import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Default gradient shown when no background video is set.
const profileBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff6a11cb), Color(0xff2575fc)],
);

/// Cover image/video and gradient only — no interactive controls.
class ProfileBackground extends StatelessWidget {
  final String coverType;
  final String coverUrl;
  final String backgroundVideoUrl;
  final VideoPlayerController? controller;
  final bool isUploading;

  const ProfileBackground({
    super.key,
    required this.coverType,
    required this.coverUrl,
    required this.backgroundVideoUrl,
    required this.controller,
    this.isUploading = false,
  });

  bool get _shouldShowVideo =>
      backgroundVideoUrl.isNotEmpty && controller != null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: _buildBackground()),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isUploading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (_shouldShowVideo) {
      return _ProfileBackgroundVideo(controller: controller!);
    }

    if (coverUrl.isNotEmpty &&
        coverType != 'video' &&
        backgroundVideoUrl.isEmpty) {
      return CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover);
    }

    return const DecoratedBox(
      decoration: BoxDecoration(gradient: profileBackgroundGradient),
    );
  }
}

/// Inline cover video — single [VideoPlayer] clipped inside the 260px header.
class _ProfileBackgroundVideo extends StatelessWidget {
  final VideoPlayerController controller;

  const _ProfileBackgroundVideo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final videoSize = controller.value.size;
            final hasSize = videoSize.width > 0 && videoSize.height > 0;

            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!controller.value.isInitialized)
                    const ColoredBox(color: Color(0xFF1A1A2E)),
                  FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: hasSize ? videoSize.width : constraints.maxWidth,
                      height: hasSize
                          ? videoSize.height
                          : constraints.maxHeight,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Fullscreen preview implementation moved to dedicated screen files

/// Cover action buttons — place as the last child in the profile [Stack]
/// so they sit above the scroll view and receive touch events.
class ProfileCoverActions extends StatelessWidget {
  final bool hasVideo;
  final bool isUploading;
  final String backgroundVideoUrl;
  final VoidCallback? onPickVideo;
  final VoidCallback? onFullscreen;

  const ProfileCoverActions({
    super.key,
    required this.hasVideo,
    this.isUploading = false,
    required this.backgroundVideoUrl,
    this.onPickVideo,
    this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final showFullscreen =
        hasVideo && onFullscreen != null && backgroundVideoUrl.isNotEmpty;

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (onPickVideo != null)
            Positioned(
              bottom: 16,
              right: 16,
              child: _CoverActionButton(
                onTap: isUploading ? () {} : onPickVideo!,
                child: isUploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.videocam, color: Colors.black),
              ),
            ),
          if (showFullscreen)
            Positioned(
              bottom: 16,
              right: onPickVideo != null ? 70 : 16,
              child: _CoverActionButton(
                onTap: onFullscreen!,
                backgroundColor: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                child: const Icon(Icons.fullscreen, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;
  final BorderRadius? borderRadius;

  const _CoverActionButton({
    required this.onTap,
    required this.child,
    this.backgroundColor = Colors.white,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
