import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class ProfileVideoFullscreenPage extends StatefulWidget {
  final String videoUrl;

  const ProfileVideoFullscreenPage({super.key, required this.videoUrl});

  @override
  State<ProfileVideoFullscreenPage> createState() =>
      _ProfileVideoFullscreenPageState();
}

class _ProfileVideoFullscreenPageState
    extends State<ProfileVideoFullscreenPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _enterFullscreen();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..setLooping(true)
      ..initialize().then((_) {
        _controller.setVolume(1.0);
        _controller.play();
        if (mounted) setState(() => _initialized = true);
      });
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    _exitFullscreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: _initialized
                    ? SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: _controller.value.size.width,
                            height: _controller.value.size.height,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: SafeArea(
                child: ClipOval(
                  child: Material(
                    color: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
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
