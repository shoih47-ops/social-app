part of '../../screens/create_post_screen.dart';

class MediaPreviewCard extends StatelessWidget {
  final List<_CroppedPostImage> selectedImages;
  final File? selectedVideo;
  final String? selectedVideoPreviewUrl;
  final Uint8List? selectedVideoThumbnail;
  final Duration? selectedVideoDuration;
  final ValueChanged<int> onPreviewImage;
  final VoidCallback onPreviewVideo;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onAddImages;
  final VoidCallback onRemoveVideo;

  const MediaPreviewCard({
    super.key,
    required this.selectedImages,
    required this.selectedVideo,
    required this.selectedVideoPreviewUrl,
    required this.selectedVideoThumbnail,
    required this.selectedVideoDuration,
    required this.onPreviewImage,
    required this.onPreviewVideo,
    required this.onRemoveImage,
    required this.onAddImages,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedImages.isNotEmpty) {
      final coverImage = selectedImages.first;

      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.deepPurple.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () => onPreviewImage(0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _CroppedImageView(
                      image: coverImage,
                      height: 210,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.58),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '1/${selectedImages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => onRemoveImage(0),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: selectedImages.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == selectedImages.length) {
                    return _AddImageTile(onTap: onAddImages);
                  }

                  final image = selectedImages[index];
                  return GestureDetector(
                    onTap: () => onPreviewImage(index),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _CroppedImageView(
                            image: image,
                            height: 70,
                            width: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => onRemoveImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.62),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    if (selectedVideo != null || selectedVideoPreviewUrl != null) {
      return Stack(
        children: [
          GestureDetector(
            onTap: onPreviewVideo,
            child: Container(
              padding: const EdgeInsets.all(6),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.white.withOpacity(0.75),
                border: Border.all(color: Colors.deepPurple.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (selectedVideoThumbnail != null)
                        Image.memory(
                          selectedVideoThumbnail!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        )
                      else
                        Container(
                          color: Colors.deepPurple.shade900,
                          child: const Center(
                            child: Icon(
                              Icons.videocam,
                              color: Colors.white,
                              size: 58,
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.58),
                            ],
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 68,
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 14,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    selectedVideoDuration == null
                                        ? '--:--'
                                        : _formatDuration(
                                            selectedVideoDuration!,
                                          ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.52),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.movie_outlined,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Video',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: onRemoveVideo,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }
}

class _CroppedImageView extends StatelessWidget {
  final _CroppedPostImage image;
  final double height;
  final double width;
  final BoxFit fit;

  const _CroppedImageView({
    required this.image,
    required this.height,
    required this.width,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || image.file == null) {
      return Image.memory(
        image.bytes,
        height: height,
        width: width,
        fit: fit,
        filterQuality: FilterQuality.high,
      );
    }

    return Image.file(
      image.file!,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddImageTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.deepPurple.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.deepPurple.shade400, size: 22),
            const SizedBox(height: 2),
            Text(
              'Add',
              style: TextStyle(
                color: Colors.deepPurple.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalImagePreviewScreen extends StatelessWidget {
  final List<_CroppedPostImage> images;
  final int initialIndex;

  const _LocalImagePreviewScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    final controller = PageController(initialPage: initialIndex);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: images.length,
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  child: _CroppedImageView(
                    image: images[index],
                    height: size.height,
                    width: size.width,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 12 + MediaQuery.of(context).padding.top,
            left: 8,
            child: SafeArea(
              child: ClipOval(
                child: Material(
                  color: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalVideoPreviewScreen extends StatefulWidget {
  final File? video;
  final String? videoUrl;

  const _LocalVideoPreviewScreen({this.video, this.videoUrl});

  @override
  State<_LocalVideoPreviewScreen> createState() =>
      _LocalVideoPreviewScreenState();
}

class _LocalVideoPreviewScreenState extends State<_LocalVideoPreviewScreen> {
  late final VideoPlayerController _controller;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.videoUrl;
    final video = widget.video;
    _controller =
        (kIsWeb && videoUrl != null
              ? VideoPlayerController.networkUrl(Uri.parse(videoUrl))
              : VideoPlayerController.file(video!))
          ..setLooping(true)
          ..initialize().then((_) {
            if (!mounted) return;

            _controller.addListener(_onVideoChanged);
            setState(() {
              _duration = _controller.value.duration;
            });
            _controller.play();
          });
  }

  void _onVideoChanged() {
    if (!mounted) return;

    setState(() {
      _position = _controller.value.position;
      _duration = _controller.value.duration;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoChanged);
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;

    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _showControls = true;
    });
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
            Positioned(
              top: 12 + MediaQuery.of(context).padding.top,
              left: 8,
              child: SafeArea(
                child: ClipOval(
                  child: Material(
                    color: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
            if (_showControls)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Slider(
                      value: _position.inMilliseconds
                          .clamp(0, _duration.inMilliseconds)
                          .toDouble(),
                      max: _duration.inMilliseconds > 0
                          ? _duration.inMilliseconds.toDouble()
                          : 1,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                      onChanged: (value) {
                        _controller.seekTo(
                          Duration(milliseconds: value.toInt()),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _format(_position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _format(_duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClipOval(
                      child: Material(
                        color: Colors.black54,
                        child: IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlay,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
