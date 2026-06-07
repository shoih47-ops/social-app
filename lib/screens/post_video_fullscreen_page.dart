import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import 'dart:async';

import '../models/post.dart';
import '../widgets/like_button.dart';
import '../widgets/comment_button.dart';
import '../utils/time_ago.dart';

import '../screens/profile_screen.dart';
import '../screens/user_profile_screen.dart';

class PostVideoFullscreenPage extends StatefulWidget {
  final Post post;

  const PostVideoFullscreenPage({super.key, required this.post});

  @override
  State<PostVideoFullscreenPage> createState() =>
      _PostVideoFullscreenPageState();
}

class _PostVideoFullscreenPageState extends State<PostVideoFullscreenPage>
    with TickerProviderStateMixin {
  late final VideoPlayerController _controller;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isMuted = false;
  late final AnimationController _heartController;
  late final AnimationController _dismissController;
  // vertical drag to dismiss (not used currently)

  void _onVideoChanged() {
    if (!mounted) return;
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    setState(() {
      _position = pos;
      _duration = dur;
    });
  }

  @override
  void initState() {
    super.initState();
    _enterFullscreen();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _controller = VideoPlayerController.network(widget.post.videoUrl)
      ..setLooping(false)
      ..setVolume(1.0)
      ..initialize().then((_) {
        if (mounted) {
          _duration = _controller.value.duration;
          _controller.addListener(_onVideoChanged);
          setState(() {});
        }
        _controller.play();
      });
  }

  Future<void> _handleDoubleTap() async {
    // animate heart
    try {
      _heartController.forward(from: 0.0);
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id);
    final doc = await postRef.get();
    final data = doc.data() ?? {};
    final List likes = List.from(data['likes'] ?? []);

    final alreadyLiked = likes.contains(user.uid);
    if (alreadyLiked) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([user.uid]),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([user.uid]),
      });

      // send notification
      if (widget.post.userId != user.uid) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final username = userDoc.data()?['username'] ?? 'Someone';
        unawaited(
          sendNotification(
            toUserId: widget.post.userId,
            type: 'like',
            fromUserId: user.uid,
            fromUsername: username,
            postId: widget.post.id,
          ),
        );
      }
    }
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  void _toggleMute() {
    if (!_controller.value.isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
      _showControls = true;
    });
  }

  void _onTap() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    try {
      _controller.removeListener(_onVideoChanged);
    } catch (_) {}
    _controller.pause();
    _controller.dispose();
    try {
      _heartController.dispose();
    } catch (_) {}
    try {
      _dismissController.dispose();
    } catch (_) {}
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onDoubleTap: _handleDoubleTap,
          child: Stack(
            children: [
              // Video
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

              // Close button
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

              // Social buttons (right)
              Positioned(
                right: 12,
                bottom: 220,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: LikeButton(
                          post: widget.post,
                          iconColor: Colors.white,
                          textColor: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),

                      CommentButton(
                        postId: widget.post.id,
                        postOwnerId: widget.post.userId,
                        iconColor: Colors.white,
                        textColor: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom gradient
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.30,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black54,
                            Colors.black87,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Caption (bottom-left)
              Positioned(
                left: 16,
                bottom: 130,
                child: SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.post.userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox();
                            }
                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>;
                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final currentUid =
                                        FirebaseAuth.instance.currentUser!.uid;

                                    if (widget.post.userId == currentUid) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ProfileScreen(userId: currentUid),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserProfileScreen(
                                            userId: widget.post.userId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundImage:
                                            userData['photoUrl'] != null &&
                                                userData['photoUrl'] != ''
                                            ? NetworkImage(userData['photoUrl'])
                                            : null,
                                        child:
                                            (userData['photoUrl'] == null ||
                                                userData['photoUrl'] == '')
                                            ? const Icon(Icons.person, size: 16)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        userData['username'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 4),
                        Text(
                          timeAgo(widget.post.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Controls (bottom)
              if (_showControls)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_controller.value.isInitialized)
                        Column(
                          children: [
                            Slider(
                              value: _position.inMilliseconds
                                  .clamp(0, _duration.inMilliseconds)
                                  .toDouble(),
                              max: _duration.inMilliseconds > 0
                                  ? _duration.inMilliseconds.toDouble()
                                  : 1.0,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white24,
                              onChanged: (v) {
                                final seekTo = Duration(
                                  milliseconds: v.toInt(),
                                );
                                _controller.seekTo(seekTo);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                          const SizedBox(width: 12),
                          ClipOval(
                            child: Material(
                              color: Colors.black54,
                              child: IconButton(
                                icon: Icon(
                                  _isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleMute,
                              ),
                            ),
                          ),
                        ],
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
