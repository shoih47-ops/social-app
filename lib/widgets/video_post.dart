import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPost extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onFullscreen;

  const VideoPost({super.key, required this.videoUrl, this.onFullscreen});

  @override
  State<VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<VideoPost> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _initializing = false;
  bool _isVisible = false;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    // Register after first frame so we can find the nearest Scrollable and
    // check visibility. We lazily initialize the VideoPlayerController only
    // when the widget becomes visible to save resources and keep scrolling smooth.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRegisterScrollListener();
    });
  }

  void _maybeRegisterScrollListener() {
    // Find the nearest Scrollable. If present, listen to scroll events to detect visibility.
    final ScrollableState? scrollable = Scrollable.of(context);
    _scrollPosition = scrollable?.position;
    if (_scrollPosition != null) {
      _scrollPosition!.addListener(_checkVisibilityOnScroll);
      // initial visibility check
      _checkVisibilityOnScroll();
    } else {
      // No scrollable ancestor: likely used in a non-scrolling context (fullscreen).
      // Initialize controller immediately so playback works.
      _ensureInitialized();
    }
  }

  void _checkVisibilityOnScroll() {
    if (!mounted) return;
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox) return;
    final RenderBox box = ro;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    final Size size = box.size;
    final Rect widgetRect = topLeft & size;

    final Size screenSize = MediaQuery.of(context).size;
    final Rect screenRect = Offset.zero & screenSize;

    // Consider visible if the widget's center is inside the screen rect
    final Offset center = widgetRect.center;
    final bool visible = screenRect.contains(center);

    if (visible && !_isVisible) {
      _isVisible = true;
      if (!_initialized) {
        _ensureInitialized();
      } else if (!_controller!.value.isPlaying) {
        _controller!.play();
        setState(() {});
      }
    } else if (!visible && _isVisible) {
      _isVisible = false;
      if (_initialized && _controller!.value.isPlaying) {
        _controller!.pause();
        setState(() {});
      }
    }
  }

  void _ensureInitialized() {
    if (_initialized || _initializing) return;
    _initializing = true;
    try {
      _controller = VideoPlayerController.network(widget.videoUrl)
        ..setLooping(true)
        ..setVolume(0);

      _controller!.initialize().then((_) {
        if (!mounted) return;
        _initialized = true;
        _initializing = false;
        setState(() {});

        // Autoplay if currently visible
        if (_isVisible && !_controller!.value.isPlaying) {
          _controller!.play();
        }
      });
    } catch (e) {
      _initializing = false;
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_checkVisibilityOnScroll);
    if (_controller != null) {
      try {
        _controller!.pause();
        _controller!.dispose();
      } catch (_) {}
      _controller = null;
    }
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) {
      // If user taps before initialization, initialize and play when ready.
      _ensureInitialized();
      return;
    }
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _initialized ? _controller!.value.aspectRatio : 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video with BoxFit.cover
          if (!_initialized)
            Container(
              color: Colors.black,
              child: const Center(child: CircularProgressIndicator()),
            )
          else
            // Use contain instead of cover so more of the original video is visible
            // and we avoid aggressive cropping. Keep rounded corners at the parent.
            Container(
              color: Colors.black,
              child: Center(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: _controller!.value.size.width == 0
                          ? MediaQuery.of(context).size.width
                          : _controller!.value.size.width,
                      height: _controller!.value.size.height == 0
                          ? (MediaQuery.of(context).size.width /
                                (_controller!.value.aspectRatio == 0
                                    ? 16 / 9
                                    : _controller!.value.aspectRatio))
                          : _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              ),
            ),

          // Tap to pause/play
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlay,
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          // Play icon when paused
          if (_initialized && !_controller!.value.isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white, size: 56),
            ),

          // Buffering/loading indicator when initialized but buffering
          if (_initialized && _controller!.value.isBuffering)
            const Center(child: CircularProgressIndicator()),

          // Fullscreen button with dark circular background
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: widget.onFullscreen,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
