part of '../../screens/create_post_screen.dart';

class _VideoTrimScreen extends StatefulWidget {
  final File videoFile;
  final Duration videoDuration;

  const _VideoTrimScreen({
    required this.videoFile,
    required this.videoDuration,
  });

  @override
  State<_VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class _TrimmedVideoResult {
  final File file;
  final Duration duration;

  const _TrimmedVideoResult({required this.file, required this.duration});
}

class _VideoTrimScreenState extends State<_VideoTrimScreen> {
  final Trimmer _trimmer = Trimmer();
  final ScrollController _timelineScrollController = ScrollController();
  double _startValue = 0;
  double _endValue = _maxVideoDuration.inMilliseconds.toDouble();
  double _currentValue = 0;
  List<Uint8List> _timelineThumbnails = [];
  bool _isLoading = true;
  bool _isLoadingTimeline = true;
  bool _isPlaying = false;
  bool _isSaving = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      await _trimmer.loadVideo(videoFile: widget.videoFile);
      _trimmer.videoPlayerController?.addListener(_onVideoPositionChanged);
      if (!mounted) return;

      setState(() {
        _endValue = min(
          widget.videoDuration.inMilliseconds,
          _maxVideoDuration.inMilliseconds,
        ).toDouble();
        _isLoading = false;
      });
      await _loadTimelineThumbnails();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingTimeline = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load video: $e')));
    }
  }

  @override
  void dispose() {
    final controller = _trimmer.videoPlayerController;
    controller?.removeListener(_onVideoPositionChanged);
    unawaited(controller?.pause() ?? Future<void>.value());
    unawaited(controller?.dispose() ?? Future<void>.value());
    _timelineScrollController.dispose();
    super.dispose();
  }

  Future<void> _pauseTrimVideo() async {
    final controller = _trimmer.videoPlayerController;
    if (controller == null) return;

    await controller.pause();
    if (!mounted) return;

    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _closeTrimScreen() async {
    if (_isClosing) return;

    _isClosing = true;
    await _pauseTrimVideo();
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  void _onVideoPositionChanged() {
    final controller = _trimmer.videoPlayerController;
    if (controller == null || !mounted) return;

    final positionMs = controller.value.position.inMilliseconds.toDouble();
    if (positionMs >= _endValue && controller.value.isPlaying) {
      controller.pause();
      controller.seekTo(Duration(milliseconds: _startValue.round()));
      setState(() {
        _isPlaying = false;
        _currentValue = _startValue;
      });
      return;
    }

    setState(() {
      _currentValue = positionMs.clamp(0.0, _videoMaxValue).toDouble();
      _isPlaying = controller.value.isPlaying;
    });
  }

  Future<void> _loadTimelineThumbnails() async {
    final durationMs = widget.videoDuration.inMilliseconds;
    if (durationMs <= 0) {
      if (!mounted) return;

      setState(() {
        _isLoadingTimeline = false;
      });
      return;
    }

    final thumbnailCount = max(10, min(40, (durationMs / 3000).ceil()));
    final thumbnails = <Uint8List>[];

    for (var index = 0; index < thumbnailCount; index++) {
      final timeMs = ((durationMs - 1) * index / thumbnailCount).round();
      final thumbnail = await video_thumbnail.VideoThumbnail.thumbnailData(
        video: widget.videoFile.path,
        imageFormat: video_thumbnail.ImageFormat.JPEG,
        timeMs: timeMs,
        maxWidth: 160,
        quality: 55,
      );

      if (thumbnail != null) {
        thumbnails.add(thumbnail);
      }
    }

    if (!mounted) return;

    setState(() {
      _timelineThumbnails = thumbnails;
      _isLoadingTimeline = false;
    });
  }

  Future<void> _togglePlayback() async {
    if (_isSaving || _isLoading) return;

    final isPlaying = await _trimmer.videoPlaybackControl(
      startValue: _startValue,
      endValue: _endValue,
    );

    if (!mounted) return;

    setState(() {
      _isPlaying = isPlaying;
    });
  }

  double get _videoMaxValue =>
      max(1, widget.videoDuration.inMilliseconds).toDouble();

  double _timelineWidth(BuildContext context) {
    final viewportWidth = MediaQuery.of(context).size.width - 36;
    final durationWidth = widget.videoDuration.inSeconds * 22.0;
    return max(viewportWidth, durationWidth);
  }

  void _setSelection({
    required double start,
    required double end,
    double? previewPosition,
    bool preview = true,
  }) {
    const minLengthMs = 1000.0;
    final maxLengthMs = _maxVideoDuration.inMilliseconds.toDouble();
    final maxValue = _videoMaxValue;
    var nextStart = start.clamp(0.0, maxValue).toDouble();
    var nextEnd = end.clamp(0.0, maxValue).toDouble();

    if (nextEnd - nextStart < minLengthMs) {
      if ((nextStart - _startValue).abs() > (nextEnd - _endValue).abs()) {
        nextStart = max(0.0, nextEnd - minLengthMs);
      } else {
        nextEnd = min(maxValue, nextStart + minLengthMs);
      }
    }

    if (nextEnd - nextStart > maxLengthMs) {
      if ((nextStart - _startValue).abs() > (nextEnd - _endValue).abs()) {
        nextStart = max(0.0, nextEnd - maxLengthMs);
      } else {
        nextEnd = min(maxValue, nextStart + maxLengthMs);
      }
    }

    setState(() {
      _startValue = nextStart;
      _endValue = nextEnd;
      _currentValue = (previewPosition ?? nextStart)
          .clamp(nextStart, nextEnd)
          .toDouble();
    });

    if (preview) {
      unawaited(_seekPreviewTo(_currentValue));
    }
  }

  void _dragStartHandle(double delta, double timelineWidth) {
    final deltaMs = delta / timelineWidth * _videoMaxValue;
    final nextStart = _startValue + deltaMs;
    _setSelection(start: nextStart, end: _endValue, previewPosition: nextStart);
  }

  void _dragEndHandle(double delta, double timelineWidth) {
    final deltaMs = delta / timelineWidth * _videoMaxValue;
    final nextEnd = _endValue + deltaMs;
    _setSelection(start: _startValue, end: nextEnd, previewPosition: nextEnd);
  }

  void _dragSelectedSegment(double delta, double timelineWidth) {
    final deltaMs = delta / timelineWidth * _videoMaxValue;
    final selectionLength = _endValue - _startValue;
    final maxStart = max(0.0, _videoMaxValue - selectionLength);
    final nextStart = (_startValue + deltaMs).clamp(0.0, maxStart).toDouble();

    _setSelection(
      start: nextStart,
      end: nextStart + selectionLength,
      previewPosition: nextStart,
    );
  }

  Future<void> _seekPreviewTo(double value) async {
    final controller = _trimmer.videoPlayerController;
    if (controller == null || _isSaving) return;

    await controller.pause();
    await controller.seekTo(Duration(milliseconds: value.round()));

    if (!mounted) return;

    setState(() {
      _isPlaying = false;
      _currentValue = value.clamp(_startValue, _endValue).toDouble();
    });
  }

  Future<void> _previewSelectedClip() async {
    final controller = _trimmer.videoPlayerController;
    if (controller == null || _isSaving) return;

    await controller.seekTo(Duration(milliseconds: _startValue.round()));
    await controller.play();

    if (!mounted) return;

    setState(() {
      _isPlaying = true;
      _currentValue = _startValue;
    });
  }

  Future<void> _saveTrimmedVideo() async {
    if (_isSaving || _isLoading) return;

    final selectedLengthMs = _endValue - _startValue;
    if (selectedLengthMs < 1000 ||
        selectedLengthMs > _maxVideoDuration.inMilliseconds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a 1 to 30 second clip')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final outputCompleter = Completer<String?>();
      await _trimmer.saveTrimmedVideo(
        startValue: _startValue,
        endValue: _endValue,
        onSave: outputCompleter.complete,
      );
      final outputPath = await outputCompleter.future;

      if (!mounted) return;

      if (outputPath == null || outputPath.isEmpty) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export trimmed video')),
        );
        return;
      }

      await _pauseTrimVideo();
      if (!mounted) return;

      Navigator.of(context).pop<_TrimmedVideoResult>(
        _TrimmedVideoResult(
          file: File(outputPath),
          duration: Duration(milliseconds: selectedLengthMs.round()),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Trim failed: $e')));
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Widget _buildThumbnailTimeline() {
    final timelineWidth = _timelineWidth(context);

    return Container(
      height: 188,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.shade200, width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        controller: _timelineScrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: timelineWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isLoadingTimeline
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : _timelineThumbnails.isEmpty
                    ? Container(color: Colors.deepPurple.shade800)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _timelineThumbnails.map((thumbnail) {
                          return SizedBox(
                            width: timelineWidth / _timelineThumbnails.length,
                            child: Image.memory(
                              thumbnail,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          );
                        }).toList(),
                      ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final startX = width * (_startValue / _videoMaxValue);
                  final endX = width * (_endValue / _videoMaxValue);
                  final markerX = width * (_currentValue / _videoMaxValue);

                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: startX,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.62),
                        ),
                      ),
                      Positioned(
                        left: endX,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.62),
                        ),
                      ),
                      Positioned(
                        left: startX,
                        top: 0,
                        bottom: 0,
                        width: max(0, endX - startX),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: _isSaving
                              ? null
                              : (details) => _dragSelectedSegment(
                                  details.delta.dx,
                                  width,
                                ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent.withValues(
                                alpha: 0.24,
                              ),
                              border: Border.all(color: Colors.white, width: 3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: markerX.clamp(0.0, width - 3).toDouble(),
                        top: 8,
                        bottom: 8,
                        child: Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: (startX - 14).clamp(0.0, width - 28).toDouble(),
                        top: 0,
                        bottom: 0,
                        child: _TrimHandle(
                          label: 'Start',
                          alignment: Alignment.centerLeft,
                          onDragUpdate: _isSaving
                              ? null
                              : (details) =>
                                    _dragStartHandle(details.delta.dx, width),
                        ),
                      ),
                      Positioned(
                        left: (endX - 14).clamp(0.0, width - 28).toDouble(),
                        top: 0,
                        bottom: 0,
                        child: _TrimHandle(
                          label: 'End',
                          alignment: Alignment.centerRight,
                          onDragUpdate: _isSaving
                              ? null
                              : (details) =>
                                    _dragEndHandle(details.delta.dx, width),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startDuration = Duration(milliseconds: _startValue.round());
    final endDuration = Duration(milliseconds: _endValue.round());
    final selectedDurationSeconds = max(
      0,
      ((_endValue - _startValue) / 1000).round(),
    );

    return WillPopScope(
      onWillPop: () async {
        await _closeTrimScreen();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.deepPurple.shade700,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Close',
            onPressed: _isSaving ? null : _closeTrimScreen,
            icon: const Icon(Icons.close),
          ),
          title: const Text('Trim video'),
          actions: [
            TextButton(
              onPressed: _isSaving || _isLoading ? null : _saveTrimmedVideo,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.deepPurple),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(child: VideoViewer(trimmer: _trimmer)),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade900,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepPurple.shade200,
                              ),
                            ),
                            child: Text(
                              'Cut: ${_formatDuration(startDuration)} - ${_formatDuration(endDuration)} (${selectedDurationSeconds}s)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _TrimStat(
                                  label: 'Start',
                                  value: _formatDuration(startDuration),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _TrimStat(
                                  label: 'End',
                                  value: _formatDuration(endDuration),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _TrimStat(
                                  label: 'Length',
                                  value: '${selectedDurationSeconds}s',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text(
                                'Choose clip',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Max ${_formatDuration(_maxVideoDuration)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildThumbnailTimeline(),
                          const SizedBox(height: 12),
                          IconButton(
                            tooltip: _isPlaying ? 'Pause' : 'Play',
                            onPressed: _togglePlayback,
                            iconSize: 58,
                            color: Colors.white,
                            icon: Icon(
                              _isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TrimHandle extends StatelessWidget {
  final String label;
  final Alignment alignment;
  final GestureDragUpdateCallback? onDragUpdate;

  const _TrimHandle({
    required this.label,
    required this.alignment,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: onDragUpdate,
      child: SizedBox(
        width: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade600,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white70),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: alignment,
              child: Container(
                width: 18,
                height: 116,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 3,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrimStat extends StatelessWidget {
  final String label;
  final String value;

  const _TrimStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
