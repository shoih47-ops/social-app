import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/post_service.dart';
import '../services/report_service.dart';
import '../services/share_service.dart';

import '../models/post.dart';
import '../widgets/like_button.dart';
import '../widgets/comment_button.dart';
import '../utils/time_ago.dart';
import '../utils/route_observer.dart';
import 'comment_screen.dart';

import '../screens/profile_screen.dart';
import '../screens/user_profile_screen.dart';

class PostVideoFullscreenPage extends StatefulWidget {
  final Post post;
  final bool openComments;

  const PostVideoFullscreenPage({
    super.key,
    required this.post,
    this.openComments = false,
  });

  @override
  State<PostVideoFullscreenPage> createState() =>
      _PostVideoFullscreenPageState();
}

class _PostVideoFullscreenPageState extends State<PostVideoFullscreenPage>
    with WidgetsBindingObserver, RouteAware {
  late final VideoPlayerController _controller;
  ModalRoute<void>? _route;
  bool _routeCovered = false;
  bool _controllerDisposed = false;
  bool _isDisposed = false;
  bool _videoListenerAttached = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isMuted = false;
  String get _caption => widget.post.text.trim();
  static const double _maxVideoZoom = 3;
  double _videoScale = 1;
  double _videoScaleStart = 1;
  Offset _videoOffset = Offset.zero;
  Timer? _timeRefreshTimer;
  // vertical drag to dismiss (not used currently)

  void _onVideoChanged() {
    if (_isDisposed || !mounted || _controllerDisposed) return;
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    _setStateIfMounted(() {
      _position = pos;
      _duration = dur;
    });
  }

  void _setStateIfMounted(VoidCallback update) {
    if (_isDisposed || !mounted) return;
    setState(update);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _enterFullscreen();
    if (widget.openComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showComments());
    }
    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _setStateIfMounted(() {});
    });
    _controller = VideoPlayerController.network(widget.post.videoUrl)
      ..setLooping(false)
      ..setVolume(1.0)
      ..initialize().then((_) {
        if (_isDisposed || !mounted || _controllerDisposed) return;
        _duration = _controller.value.duration;
        _controller.addListener(_onVideoChanged);
        _videoListenerAttached = true;
        _setStateIfMounted(() {});
        if (_canPlayVideo) {
          _controller.play();
        }
      });
  }

  bool get _canPlayVideo =>
      mounted &&
      !_isDisposed &&
      !_controllerDisposed &&
      !_routeCovered &&
      _lifecycleState == AppLifecycleState.resumed;

  Future<void> _pauseVideo() async {
    if (_isDisposed || _controllerDisposed || !_controller.value.isInitialized) {
      return;
    }
    await _controller.pause();
  }

  Future<void> _prepareForNavigation() async {
    if (_isDisposed) return;
    _routeCovered = true;
    await _pauseVideo();
  }

  void _resumeVideoIfAllowed() {
    if (_canPlayVideo && _controller.value.isInitialized) {
      _controller.play();
    }
  }

  Future<void> _showComments() async {
    if (_isDisposed || !mounted) return;
    await _prepareForNavigation();
    if (_isDisposed || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: CommentScreen(
            postId: widget.post.id,
            postOwnerId: widget.post.userId,
          ),
        );
      },
    );
  }

  Future<void> _openProfile() async {
    if (_isDisposed) return;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    await _prepareForNavigation();
    if (_isDisposed || !mounted) return;

    if (widget.post.userId == currentUid) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: currentUid),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: widget.post.userId),
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<void>(context);
    if (route != null && route != _route) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (_isDisposed) return;
    _routeCovered = true;
    unawaited(_pauseVideo());
  }

  @override
  void didPopNext() {
    if (_isDisposed) return;
    _routeCovered = false;
    _resumeVideoIfAllowed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _resumeVideoIfAllowed();
    } else {
      unawaited(_pauseVideo());
    }
  }

  void _resetVideoZoom() {
    _setStateIfMounted(() {
      _videoScale = 1;
      _videoScaleStart = 1;
      _videoOffset = Offset.zero;
    });
  }

  Size _fittedVideoSize(Size viewport, double aspectRatio) {
    if (viewport.width <= 0 || viewport.height <= 0 || aspectRatio <= 0) {
      return viewport;
    }

    final viewportAspectRatio = viewport.width / viewport.height;
    if (aspectRatio > viewportAspectRatio) {
      return Size(viewport.width, viewport.width / aspectRatio);
    }
    return Size(viewport.height * aspectRatio, viewport.height);
  }

  Offset _clampVideoOffset({
    required Offset offset,
    required Size viewport,
    required Size videoSize,
    required double scale,
  }) {
    if (scale <= 1) return Offset.zero;

    final scaledWidth = videoSize.width * scale;
    final scaledHeight = videoSize.height * scale;
    final maxDx = math.max(0.0, (scaledWidth - viewport.width) / 2);
    final maxDy = math.max(0.0, (scaledHeight - viewport.height) / 2);

    return Offset(
      offset.dx.clamp(-maxDx, maxDx).toDouble(),
      offset.dy.clamp(-maxDy, maxDy).toDouble(),
    );
  }

  void _handleVideoScaleStart(ScaleStartDetails details) {
    _videoScaleStart = _videoScale;
  }

  void _handleVideoScaleUpdate(
    ScaleUpdateDetails details,
    Size viewport,
    Size videoSize,
  ) {
    final nextScale = (_videoScaleStart * details.scale)
        .clamp(1.0, _maxVideoZoom)
        .toDouble();
    final nextOffset = _clampVideoOffset(
      offset: nextScale <= 1
          ? Offset.zero
          : _videoOffset + details.focalPointDelta,
      viewport: viewport,
      videoSize: videoSize,
      scale: nextScale,
    );

    _setStateIfMounted(() {
      _videoScale = nextScale;
      _videoOffset = nextOffset;
    });
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _togglePlay() {
    if (_isDisposed || _controllerDisposed || !_controller.value.isInitialized) {
      return;
    }
    _setStateIfMounted(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _showControls = true;
    });
  }

  void _toggleMute() {
    if (_isDisposed || _controllerDisposed || !_controller.value.isInitialized) {
      return;
    }
    _setStateIfMounted(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
      _showControls = true;
    });
  }

  void _onTap() {
    _setStateIfMounted(() {
      _showControls = !_showControls;
    });
  }

  void _seekVideo(double value) {
    if (_isDisposed || _controllerDisposed || !_controller.value.isInitialized) {
      return;
    }
    _controller.seekTo(Duration(milliseconds: value.toInt()));
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF6D28D9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMoodCategoryChips() {
    final chips = <Widget>[
      if (widget.post.mood.trim().isNotEmpty)
        _buildMetaChip(widget.post.mood.trim()),
      if (widget.post.category.trim().isNotEmpty)
        _buildMetaChip(widget.post.category.trim()),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 3),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Widget _buildCaptionText(BuildContext context) {
    final caption = _caption;
    if (caption.isEmpty) return const SizedBox.shrink();

    const style = TextStyle(
      color: Colors.white70,
      fontSize: 13,
      height: 1.3,
      shadows: [
        Shadow(
          color: Colors.black87,
          blurRadius: 6,
          offset: Offset(0, 1),
        ),
      ],
    );

    final actionStyle = style.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaleFactor = MediaQuery.textScaleFactorOf(context);
        final direction = Directionality.of(context);
        final maxWidth = constraints.maxWidth;
        const maxLines = 3;

        final fullPainter = TextPainter(
          text: TextSpan(text: caption, style: style),
          textDirection: direction,
          maxLines: maxLines,
          textScaleFactor: textScaleFactor,
        )..layout(maxWidth: maxWidth);

        if (!fullPainter.didExceedMaxLines) {
          return Text(caption, style: style);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              caption,
              style: style,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showFullCaption(context),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('More', style: actionStyle),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFullCaption(BuildContext context) {
    final caption = _caption;
    if (caption.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Text(
                caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _controllerDisposed = true;
    _timeRefreshTimer?.cancel();
    if (_videoListenerAttached) {
      _controller.removeListener(_onVideoChanged);
      _videoListenerAttached = false;
    }
    unawaited(_controller.dispose());
    unawaited(_exitFullscreen());
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
          onDoubleTap: _resetVideoZoom,
          child: Stack(
            children: [
              // Video
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (!_controller.value.isInitialized) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final viewport = constraints.biggest;
                    final videoSize = _fittedVideoSize(
                      viewport,
                      _controller.value.aspectRatio,
                    );

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: _handleVideoScaleStart,
                      onScaleUpdate: (details) {
                        _handleVideoScaleUpdate(details, viewport, videoSize);
                      },
                      child: Center(
                        child: Transform.translate(
                          offset: _clampVideoOffset(
                            offset: _videoOffset,
                            viewport: viewport,
                            videoSize: videoSize,
                            scale: _videoScale,
                          ),
                          child: Transform.scale(
                            scale: _videoScale,
                            child: SizedBox(
                              width: videoSize.width,
                              height: videoSize.height,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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

              // Popup menu (top-right): Delete for owner, Report for others
              Positioned(
                top: 12 + MediaQuery.of(context).padding.top,
                right: 8,
                child: SafeArea(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.post.userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      // If user data not ready, still render a transparent menu placeholder
                      final currentUid = FirebaseAuth.instance.currentUser?.uid;
                      final isOwner =
                          currentUid != null &&
                          currentUid == widget.post.userId;

                      return PopupMenuButton<String>(
                        color: Colors.black54,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) async {
                          if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Post'),
                                content: const Text(
                                  'Are you sure you want to delete this post?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final deleteFuture = PostService.deleteVideoPost(
                                widget.post.id,
                              );
                              if (mounted) Navigator.pop(context);
                              await deleteFuture;
                            }
                          } else if (value == 'report') {
                            final cu = FirebaseAuth.instance.currentUser;
                            if (cu != null) {
                              await ReportService.reportPost(
                                postId: widget.post.id,
                                userId: cu.uid,
                                reason: 'Inappropriate Content',
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Post reported'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        itemBuilder: (context) => isOwner
                            ? [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete Post'),
                                ),
                              ]
                            : [
                                const PopupMenuItem(
                                  value: 'report',
                                  child: Text('Report Post'),
                                ),
                              ],
                      );
                    },
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
                        onBeforeOpen: _prepareForNavigation,
                      ),
                      const SizedBox(height: 16),

                      IconButton(
                        tooltip: 'Share',
                        onPressed: () {
                          ShareService.sharePostLink(context, widget.post);
                        },
                        icon: const Icon(Icons.ios_share_outlined, size: 24),
                        color: Colors.white,
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
                                  onTap: _openProfile,
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
                        _buildMoodCategoryChips(),
                        Text(
                          TimeAgoHelper.format(
                            widget.post.createdAt,
                            display: TimeAgoDisplay.detail,
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (_caption.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildCaptionText(context),
                        ],
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
                              onChanged: _seekVideo,
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
