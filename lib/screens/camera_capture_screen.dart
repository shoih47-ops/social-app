import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum CameraCaptureType { photo, video }

const Duration _maxCameraRecordingDuration = Duration(seconds: 30);

class CameraCaptureResult {
  final XFile file;
  final CameraCaptureType type;

  const CameraCaptureResult({required this.file, required this.type});
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;
  List<CameraDescription>? _availableCameras;
  late Future<void> _initializationFuture;
  int _initializationGeneration = 0;
  bool _isInitializing = false;
  CameraCaptureType _mode = CameraCaptureType.photo;
  bool _isCapturing = false;
  bool _isRecording = false;
  bool _isClosing = false;
  bool _isAppActive = true;
  bool _isReleasingCamera = false;
  FlashMode _flashMode = FlashMode.off;
  Timer? _recordingTimer;
  final Stopwatch _recordingStopwatch = Stopwatch();
  Duration _recordingDuration = Duration.zero;
  XFile? _capturedFile;
  CameraCaptureType? _capturedType;
  VideoPlayerController? _videoPreviewController;
  Future<void>? _videoPreviewFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializationFuture = _initializeCamera();
  }

  Future<void> _initializeCamera({CameraDescription? camera}) async {
    final generation = ++_initializationGeneration;
    _isInitializing = true;
    CameraController? controller;

    try {
      final previousController = _controller;
      _controller = null;
      if (previousController != null) {
        await _disposeCameraController(previousController);
      }

      var cameras = _availableCameras;
      if (cameras == null) {
        cameras = await availableCameras().timeout(const Duration(seconds: 15));
        _availableCameras = cameras;
      }
      final resolvedCameras = cameras;
      if (resolvedCameras.isEmpty) {
        throw const _CameraInitializationError('No camera is available.');
      }

      _camera =
          camera ??
          _camera ??
          resolvedCameras.firstWhere(
            (availableCamera) =>
                availableCamera.lensDirection == CameraLensDirection.back,
            orElse: () => resolvedCameras.first,
          );

      controller = CameraController(
        _camera!,
        ResolutionPreset.max,
        enableAudio: true,
      );
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 30));

      if (!mounted || generation != _initializationGeneration) {
        await _disposeCameraController(controller);
        if (identical(_controller, controller)) _controller = null;
        return;
      }

      await _enableAutoFocus(controller);
      try {
        await controller.setFlashMode(FlashMode.off);
        _flashMode = FlashMode.off;
      } catch (_) {
        // Flash is optional and is not exposed by every camera.
      }
    } catch (error) {
      if (controller != null) await _disposeCameraController(controller);
      if (identical(_controller, controller)) _controller = null;

      if (error is _CameraInitializationError) rethrow;
      if (error is TimeoutException) {
        throw const _CameraInitializationError(
          'Camera initialization timed out. Please try again.',
        );
      }
      if (error is CameraException) {
        throw _CameraInitializationError(_cameraErrorMessage(error));
      }
      throw _CameraInitializationError('Could not start the camera: $error');
    } finally {
      if (generation == _initializationGeneration) {
        _isInitializing = false;
      }
    }
  }

  Future<void> _disposeCameraController(CameraController controller) async {
    try {
      await controller.dispose().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Native camera cleanup must never leave this route waiting forever.
    }
  }

  Future<void> _enableAutoFocus(CameraController controller) async {
    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {
      // Some cameras use fixed focus and do not expose focus controls.
    }
    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {
      // Exposure controls are not available on every platform or lens.
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
        return 'Camera permission was denied. Allow camera access and try again.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission is disabled. Enable it in device settings and try again.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      case 'AudioAccessDenied':
        return 'Microphone permission is required to record video.';
      case 'AudioAccessDeniedWithoutPrompt':
        return 'Microphone permission is disabled. Enable it in device settings to record video.';
      case 'AudioAccessRestricted':
        return 'Microphone access is restricted on this device.';
      default:
        return error.description ?? 'Could not initialize the camera.';
    }
  }

  void _retryInitialization() {
    if (_isInitializing) return;
    setState(() {
      _initializationFuture = _initializeCamera();
    });
  }

  bool get _hasAlternateCamera {
    final cameras = _availableCameras;
    final currentCamera = _camera;
    if (cameras == null || currentCamera == null) return false;

    final targetDirection =
        currentCamera.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    return cameras.any((camera) => camera.lensDirection == targetDirection);
  }

  bool get _canSwitchCamera =>
      !_isInitializing && !_isCapturing && !_isRecording && _hasAlternateCamera;

  CameraDescription? get _backCamera {
    final cameras = _availableCameras;
    if (cameras == null) return null;

    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        return camera;
      }
    }
    return null;
  }

  void _switchCamera() {
    if (!_canSwitchCamera) return;

    final cameras = _availableCameras;
    final currentCamera = _camera;
    if (cameras == null || currentCamera == null) return;

    final targetDirection =
        currentCamera.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    CameraDescription? targetCamera;
    for (final camera in cameras) {
      if (camera.lensDirection == targetDirection) {
        targetCamera = camera;
        break;
      }
    }

    if (targetCamera == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No alternate camera is available.')),
      );
      return;
    }

    setState(() {
      _initializationFuture = _initializeCamera(camera: targetCamera);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_capturedFile != null || _isClosing) return;
    _isAppActive = state == AppLifecycleState.resumed;
    final controller = _controller;
    if (state == AppLifecycleState.resumed) {
      if (!_isInitializing &&
          !_isReleasingCamera &&
          (controller == null || !controller.value.isInitialized)) {
        setState(() {
          _initializationFuture = _initializeCamera();
        });
      }
    } else if (controller != null && controller.value.isInitialized) {
      unawaited(_releaseCameraForBackground(controller));
    }
  }

  Future<void> _releaseCameraForBackground(CameraController controller) async {
    if (_isReleasingCamera) return;
    _isReleasingCamera = true;
    _initializationGeneration++;
    _isInitializing = false;
    _stopRecordingTimer();
    try {
      if (_isRecording) {
        await _stopVideoRecording(showPreview: false);
      }
      if (!identical(_controller, controller)) return;
      _controller = null;
      await _disposeCameraController(controller);
    } finally {
      _isReleasingCamera = false;
      if (mounted) {
        if (_isAppActive) {
          setState(() => _initializationFuture = _initializeCamera());
        } else {
          setState(() {});
        }
      }
    }
  }

  void _setMode(CameraCaptureType mode) {
    if (_isCapturing || _isRecording || _mode == mode) return;

    if (mode == CameraCaptureType.video &&
        _camera?.lensDirection == CameraLensDirection.front) {
      final backCamera = _backCamera;
      if (backCamera != null) {
        setState(() {
          _mode = mode;
          _initializationFuture = _initializeCamera(camera: backCamera);
        });
        return;
      }
    }

    setState(() => _mode = mode);
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      await _showCapturedPreview(file, CameraCaptureType.photo);
    } on CameraException catch (error) {
      _showCameraError(error);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _toggleVideoRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      if (_isRecording) {
        await _stopVideoRecording(showPreview: true);
      } else {
        await controller.startVideoRecording();
        if (!mounted) return;
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        _startRecordingTimer();
      }
    } on CameraException catch (error) {
      _showCameraError(error);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingStopwatch
      ..reset()
      ..start();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !_isRecording) return;
      final elapsed = _recordingStopwatch.elapsed;
      final reachedLimit = elapsed >= _maxCameraRecordingDuration;
      setState(() {
        _recordingDuration = reachedLimit
            ? _maxCameraRecordingDuration
            : elapsed;
      });
      if (reachedLimit) unawaited(_stopRecordingAtLimit());
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStopwatch.stop();
  }

  Future<void> _stopRecordingAtLimit() async {
    if (_isCapturing || !_isRecording) return;
    setState(() => _isCapturing = true);
    try {
      await _stopVideoRecording(showPreview: true);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<XFile?> _stopVideoRecording({required bool showPreview}) async {
    final controller = _controller;
    if (controller == null || !_isRecording) return null;

    _stopRecordingTimer();
    XFile? file;
    try {
      if (controller.value.isRecordingVideo) {
        file = await controller.stopVideoRecording();
      }
    } on CameraException catch (error) {
      if (mounted) _showCameraError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });
      } else {
        _isRecording = false;
      }
    }

    if (file != null && showPreview && mounted) {
      await _showCapturedPreview(file, CameraCaptureType.video);
    }
    return file;
  }

  Future<void> _showCapturedPreview(XFile file, CameraCaptureType type) async {
    final cameraController = _controller;
    _controller = null;
    _initializationGeneration++;
    if (cameraController != null) {
      await _disposeCameraController(cameraController);
    }
    if (!mounted) return;

    VideoPlayerController? videoController;
    Future<void>? videoFuture;
    if (type == CameraCaptureType.video) {
      final previewController = VideoPlayerController.file(File(file.path));
      videoController = previewController;
      videoFuture = previewController
          .initialize()
          .timeout(const Duration(seconds: 15))
          .then((_) async {
            await previewController.setLooping(true);
            await previewController.play();
          });
    }

    setState(() {
      _capturedFile = file;
      _capturedType = type;
      _videoPreviewController = videoController;
      _videoPreviewFuture = videoFuture;
      _isCapturing = false;
    });
  }

  Future<void> _retake() async {
    if (_isCapturing) return;
    final videoController = _videoPreviewController;
    setState(() {
      _capturedFile = null;
      _capturedType = null;
      _videoPreviewController = null;
      _videoPreviewFuture = null;
      _initializationFuture = _initializeCamera();
    });
    await videoController?.dispose();
  }

  Future<void> _useCapture() async {
    final file = _capturedFile;
    final type = _capturedType;
    if (file == null || type == null) return;
    if (type == CameraCaptureType.video) {
      try {
        await _videoPreviewFuture;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not preview this video.')),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(CameraCaptureResult(file: file, type: type));
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flash is not available on this camera.'),
          ),
        );
      }
    }
  }

  void _showCameraError(CameraException error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.description ?? error.code)));
  }

  Future<void> _close() async {
    if (_isClosing) return;
    _isClosing = true;
    final controller = _controller;
    if (_isRecording && controller != null) {
      await _stopVideoRecording(showPreview: false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializationGeneration++;
    _isInitializing = false;
    _stopRecordingTimer();
    _videoPreviewController?.dispose();
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(_disposeCameraController(controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedFile != null) return _buildCapturedPreview();

    return PopScope(
      canPop: !_isCapturing && !_isRecording,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isRecording) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FutureBuilder<void>(
          future: _initializationFuture,
          builder: (context, snapshot) {
            final controller = _controller;
            final isReady =
                snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError &&
                controller != null &&
                controller.value.isInitialized;

            return Stack(
              fit: StackFit.expand,
              children: [
                if (isReady)
                  _buildFullscreenPreview(context, controller)
                else if (snapshot.hasError)
                  _CameraErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _retryInitialization,
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 8,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: _isCapturing ? null : _close,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                if (isReady)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 8,
                    child: IconButton(
                      tooltip: _isRecording
                          ? 'Stop recording before switching camera'
                          : 'Switch camera',
                      onPressed: _canSwitchCamera ? _switchCamera : null,
                      icon: Icon(
                        Icons.cameraswitch_outlined,
                        color: _canSwitchCamera ? Colors.white : Colors.white54,
                        size: 30,
                      ),
                    ),
                  ),
                if (isReady)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 58,
                    child: IconButton(
                      tooltip: _flashMode == FlashMode.off
                          ? 'Turn flash on'
                          : 'Turn flash off',
                      onPressed: _isCapturing ? null : _toggleFlash,
                      icon: Icon(
                        _flashMode == FlashMode.off
                            ? Icons.flash_off
                            : Icons.flash_on,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                if (isReady && _isRecording)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 18,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _RecordingTimer(_recordingDuration),
                    ),
                  ),
                if (isReady) _buildCaptureControls(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullscreenPreview(
    BuildContext context,
    CameraController controller,
  ) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final previewWidth = isPortrait ? previewSize.height : previewSize.width;
    final previewHeight = isPortrait ? previewSize.width : previewSize.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            unawaited(
              _focusAtPoint(
                controller,
                details.localPosition,
                viewportSize,
                Size(previewWidth, previewHeight),
              ),
            );
          },
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _focusAtPoint(
    CameraController controller,
    Offset tapPosition,
    Size viewportSize,
    Size previewSize,
  ) async {
    if (!controller.value.isInitialized || _isCapturing) return;

    final scale = math.max(
      viewportSize.width / previewSize.width,
      viewportSize.height / previewSize.height,
    );
    final renderedWidth = previewSize.width * scale;
    final renderedHeight = previewSize.height * scale;
    final croppedX = (renderedWidth - viewportSize.width) / 2;
    final croppedY = (renderedHeight - viewportSize.height) / 2;

    var normalizedX = ((tapPosition.dx + croppedX) / renderedWidth)
        .clamp(0.0, 1.0)
        .toDouble();
    final normalizedY = ((tapPosition.dy + croppedY) / renderedHeight)
        .clamp(0.0, 1.0)
        .toDouble();
    if (_camera?.lensDirection == CameraLensDirection.front) {
      normalizedX = 1.0 - normalizedX;
    }

    final focusPoint = Offset(normalizedX, normalizedY);
    try {
      await controller.setFocusPoint(focusPoint);
      await controller.setExposurePoint(focusPoint);
    } catch (_) {
      // Tap-to-focus is best effort because some lenses use fixed focus.
    }
  }

  Widget _buildCapturedPreview() {
    final file = _capturedFile!;
    final isVideo = _capturedType == CameraCaptureType.video;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_retake());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              FutureBuilder<void>(
                future: _videoPreviewFuture,
                builder: (context, snapshot) {
                  final videoController = _videoPreviewController;
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not preview this video.',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done ||
                      videoController == null ||
                      !videoController.value.isInitialized) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  return Center(
                    child: AspectRatio(
                      aspectRatio: videoController.value.aspectRatio,
                      child: VideoPlayer(videoController),
                    ),
                  );
                },
              )
            else
              Image.file(File(file.path), fit: BoxFit.contain),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 0,
              right: 0,
              child: Text(
                isVideo ? 'Video Preview' : 'Photo Preview',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retake,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _useCapture,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(isVideo ? 'Use Video' : 'Use Photo'),
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

  Widget _buildCaptureControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.paddingOf(context).bottom + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeButton(
                    label: 'Photo',
                    selected: _mode == CameraCaptureType.photo,
                    onTap: () => _setMode(CameraCaptureType.photo),
                  ),
                  _ModeButton(
                    label: 'Video',
                    selected: _mode == CameraCaptureType.video,
                    onTap: () => _setMode(CameraCaptureType.video),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _isCapturing
                ? null
                : _mode == CameraCaptureType.photo
                ? _takePhoto
                : _toggleVideoRecording,
            child: _CaptureButton(mode: _mode, isRecording: _isRecording),
          ),
        ],
      ),
    );
  }
}

class _CameraInitializationError implements Exception {
  final String message;

  const _CameraInitializationError(this.message);

  @override
  String toString() => message;
}

class _CameraErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CameraErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final CameraCaptureType mode;
  final bool isRecording;

  const _CaptureButton({required this.mode, required this.isRecording});

  @override
  Widget build(BuildContext context) {
    final isPhoto = mode == CameraCaptureType.photo;

    return Container(
      width: 78,
      height: 78,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isPhoto ? Colors.white : Colors.red,
          shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isRecording ? BorderRadius.circular(8) : null,
        ),
      ),
    );
  }
}

class _RecordingTimer extends StatelessWidget {
  final Duration duration;

  const _RecordingTimer(this.duration);

  @override
  Widget build(BuildContext context) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.red, size: 10),
          const SizedBox(width: 7),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
