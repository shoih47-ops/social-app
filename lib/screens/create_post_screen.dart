import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/video_trimmer.dart';
import '../services/cloudinary_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;
import '../services/post_service.dart';

part '../widgets/create_post/mood_selector.dart';
part '../widgets/create_post/category_selector.dart';
part '../widgets/create_post/media_preview_card.dart';
part '../widgets/create_post/media_action_buttons.dart';
part '../widgets/create_post/video_trim_screen.dart';

const Duration _maxVideoDuration = Duration(seconds: 30);

class CreatePostScreen extends StatefulWidget {
  final VoidCallback? onPostSuccess;

  const CreatePostScreen({super.key, this.onPostSuccess});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _ImageCropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const _ImageCropScreen({required this.imageBytes});

  @override
  State<_ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<_ImageCropScreen> {
  final CropController _cropController = CropController();
  bool _isCropping = false;

  void _finishCrop(CropResult result) {
    if (!mounted) return;

    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() {
          _isCropping = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not crop image')));
    }
  }

  void _cropImage() {
    if (_isCropping) return;

    setState(() {
      _isCropping = true;
    });
    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade700,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 64,
              color: Colors.deepPurple.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: _isCropping
                        ? null
                        : () => Navigator.of(context).pop<Uint8List>(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Crop image',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Done',
                    onPressed: _isCropping ? null : _cropImage,
                    icon: _isCropping
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.check, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.black,
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  onCropped: _finishCrop,
                  interactive: true,
                  fixCropRect: false,
                  initialRectBuilder: InitialRectBuilder.withBuilder((
                    _,
                    imageRect,
                  ) {
                    final cropWidth = imageRect.width * 0.76;
                    final cropHeight = imageRect.height * 0.76;
                    final left =
                        imageRect.left + (imageRect.width - cropWidth) / 2;
                    final top =
                        imageRect.top + (imageRect.height - cropHeight) / 2;

                    return Rect.fromLTWH(left, top, cropWidth, cropHeight);
                  }),
                  baseColor: Colors.black,
                  maskColor: Colors.black.withOpacity(0.55),
                  radius: 12,
                  progressIndicator: const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  ),
                  cornerDotBuilder: (size, edgeAlignment) {
                    return const DotControl(color: Colors.deepPurple);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final textController = TextEditingController();
  final List<String> _placeholderPrompts = const [
    'What happened today?',
    'What made you smile today?',
    'What challenge did you face today?',
    'Share a real moment...',
    "What's on your mind today?",
  ];
  final List<String> _moods = const [
    '😊 Happy',
    '😔 Sad',
    '😴 Tired',
    '🤔 Thinking',
    '🎉 Excited',
    '😤 Frustrated',
  ];
  final List<String> _categories = const [
    '🏠 Daily Life',
    '💼 Work',
    '🎓 Study',
    '❤️ Relationship',
    '💭 Thoughts',
    '💪 Struggle',
    '🏆 Achievement',
  ];

  File? _selectedImage;
  File? _selectedVideo;
  Uint8List? _selectedVideoThumbnail;
  Duration? _selectedVideoDuration;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadStatus = '';

  bool isFocused = false;
  late final String _placeholderPrompt;
  String? _selectedMood;
  String? _selectedCategory;

  FocusNode focusNode = FocusNode();

  Future<void> _pickImageFrom(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1080,
    );

    if (pickedFile != null) {
      final croppedFile = await _openCropScreen(File(pickedFile.path));

      if (croppedFile == null || !mounted) return;

      setState(() {
        _selectedImage = File(croppedFile.path);
        _selectedVideo = null;
        _selectedVideoThumbnail = null;
        _selectedVideoDuration = null;
      });
    }
  }

  Future<File?> _openCropScreen(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    if (!mounted) return null;

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImageCropScreen(imageBytes: imageBytes),
      ),
    );

    if (croppedBytes == null) return null;

    final croppedFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'experience_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await croppedFile.writeAsBytes(croppedBytes, flush: true);

    return croppedFile;
  }

  Future<void> _pickVideoFrom(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: source);

    if (pickedFile != null) {
      var file = File(pickedFile.path);

      try {
        var duration = await _readVideoDuration(file);
        if (duration > _maxVideoDuration) {
          if (!mounted) return;

          final trimmedVideo = await Navigator.of(context)
              .push<_TrimmedVideoResult>(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => _VideoTrimScreen(
                    videoFile: file,
                    videoDuration: duration,
                  ),
                ),
              );

          if (trimmedVideo == null) return;

          file = trimmedVideo.file;
          duration = trimmedVideo.duration;

          if (duration > _maxVideoDuration) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Trimmed video must be 30 seconds or shorter'),
              ),
            );
            return;
          }
        }

        final thumbnail = await video_thumbnail.VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: video_thumbnail.ImageFormat.JPEG,
          maxWidth: 720,
          quality: 75,
        );

        if (!mounted) return;

        setState(() {
          _selectedVideo = file;
          _selectedImage = null;
          _selectedVideoThumbnail = thumbnail;
          _selectedVideoDuration = duration;
        });
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to read video: $e')));
      }
    }
  }

  Future<Duration> _readVideoDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _pickFromCameraChoice() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Capture'),
        content: const Text('Take a photo or record a video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('photo'),
            child: const Text('Photo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('video'),
            child: const Text('Video'),
          ),
        ],
      ),
    );

    if (choice == 'photo') {
      await _pickImageFrom(ImageSource.camera);
    } else if (choice == 'video') {
      await _pickVideoFrom(ImageSource.camera);
    }
  }

  String username = "";
  String userPhoto = "";

  @override
  void initState() {
    super.initState();
    _placeholderPrompt =
        _placeholderPrompts[Random().nextInt(_placeholderPrompts.length)];
    loadUser();

    focusNode.addListener(() {
      setState(() {
        isFocused = focusNode.hasFocus;
      });
    });

    textController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    setState(() {
      username = data?['username'] ?? '';
      userPhoto = data?['photoUrl'] ?? '';
    });
  }

  void _setUploadProgress(String status, double progress) {
    if (!mounted) return;

    setState(() {
      _uploadStatus = status;
      _uploadProgress = progress.clamp(0, 1).toDouble();
    });
  }

  Widget _buildUploadProgress() {
    final percent = (_uploadProgress * 100).clamp(0, 100).round();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$_uploadStatus $percent%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9F6FC),
      appBar: AppBar(
        title: const Text(
          "Share something real",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),

                // Post Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(28),

                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: isFocused
                              ? Colors.deepPurple.withOpacity(0.18)
                              : Colors.deepPurple.withOpacity(0.05),
                          blurRadius: isFocused ? 30 : 15,

                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      focusNode: focusNode,
                      controller: textController,
                      minLines: 6,
                      maxLines: null,

                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,

                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.7,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: _placeholderPrompt,
                        border: InputBorder.none,

                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 24,
                        ),

                        hintStyle: TextStyle(
                          fontSize: 22,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 10, right: 22),
                  child: CharacterCounter(count: textController.text.length),
                ),

                SizedBox(height: 18),

                if (_selectedImage != null || _selectedVideo != null) ...[
                  MediaPreviewCard(
                    selectedImage: _selectedImage,
                    selectedVideo: _selectedVideo,
                    selectedVideoThumbnail: _selectedVideoThumbnail,
                    selectedVideoDuration: _selectedVideoDuration,
                    onPreviewImage: () {
                      final image = _selectedImage;
                      if (image == null) return;

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              _LocalImagePreviewScreen(image: image),
                        ),
                      );
                    },
                    onPreviewVideo: () {
                      final video = _selectedVideo;
                      if (video == null) return;

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              _LocalVideoPreviewScreen(video: video),
                        ),
                      );
                    },
                    onRemoveImage: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                    onRemoveVideo: () {
                      setState(() {
                        _selectedVideo = null;
                        _selectedVideoThumbnail = null;
                        _selectedVideoDuration = null;
                      });
                    },
                  ),
                  SizedBox(height: 24),
                ],

                MoodSelector(
                  options: _moods,
                  selectedValue: _selectedMood,
                  onSelected: (value) {
                    setState(() {
                      _selectedMood = value;
                    });
                  },
                ),

                SizedBox(height: 22),

                CategorySelector(
                  options: _categories,
                  selectedValue: _selectedCategory,
                  onSelected: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),

                SizedBox(height: 24),

                MediaActionButtons(
                  onCameraTap: _pickFromCameraChoice,
                  onGalleryTap: () {
                    unawaited(_pickImageFrom(ImageSource.gallery));
                  },
                  onVideoTap: () {
                    unawaited(_pickVideoFrom(ImageSource.gallery));
                  },
                ),

                SizedBox(height: 32),

                // Post Button
                GestureDetector(
                  onTap: () async {
                    if (_isUploading) return;
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    if (textController.text.trim().isEmpty &&
                        _selectedImage == null &&
                        _selectedVideo == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Write something or add a photo/video"),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _isUploading = true;
                      _uploadProgress = 0;
                      _uploadStatus = _selectedVideo != null
                          ? 'Uploading video...'
                          : _selectedImage != null
                          ? 'Uploading image...'
                          : 'Sharing...';
                    });

                    try {
                      String imageUrl = '';
                      String videoUrl = '';
                      String type = 'image';

                      if (_selectedVideo != null) {
                        type = 'video';

                        // generate thumbnail bytes
                        final thumbData =
                            await video_thumbnail.VideoThumbnail.thumbnailData(
                              video: _selectedVideo!.path,
                              imageFormat: video_thumbnail.ImageFormat.JPEG,
                              maxWidth: 720,
                              quality: 75,
                            );

                        String thumbUrl = '';
                        if (thumbData != null) {
                          thumbUrl = await CloudinaryService.uploadBytesAsImage(
                            thumbData,
                            onProgress: (progress) {
                              _setUploadProgress(
                                'Uploading video...',
                                progress * 0.2,
                              );
                            },
                          );
                        }

                        // upload compressed video (CloudinaryService compresses internally)
                        videoUrl = await CloudinaryService.uploadVideo(
                          _selectedVideo!,
                          onProgress: (progress) {
                            _setUploadProgress(
                              'Uploading video...',
                              0.2 + (progress * 0.75),
                            );
                          },
                        );

                        imageUrl =
                            thumbUrl; // store thumbnail as imageUrl for feed
                      } else if (_selectedImage != null) {
                        imageUrl = await CloudinaryService.uploadImage(
                          _selectedImage!,
                          onProgress: (progress) {
                            _setUploadProgress(
                              'Uploading image...',
                              progress * 0.95,
                            );
                          },
                        );
                        type = 'image';
                      }

                      _setUploadProgress('Finishing post...', 0.96);

                      await PostService.addPost(
                        text: textController.text,
                        imageUrl: imageUrl,
                        videoUrl: videoUrl,
                        type: type,
                        mood: _selectedMood ?? '',
                        category: _selectedCategory ?? '',
                      );

                      textController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _selectedImage = null;
                        _selectedVideo = null;
                        _selectedVideoThumbnail = null;
                        _selectedVideoDuration = null;
                        _selectedMood = null;
                        _selectedCategory = null;
                        _isUploading = false;
                        _uploadProgress = 0;
                        _uploadStatus = '';
                      });

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text("Post uploaded successfully"),
                        ),
                      );
                      widget.onPostSuccess?.call();
                    } catch (e) {
                      setState(() {
                        _isUploading = false;
                        _uploadProgress = 0;
                        _uploadStatus = '';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Upload failed: $e')),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: _isUploading ? 72 : 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isUploading
                            ? [
                                Colors.deepPurple.shade200,
                                Colors.deepPurple.shade300,
                              ]
                            : [
                                Colors.deepPurple.shade300,
                                Colors.deepPurple.shade500,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.25),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isUploading
                          ? _buildUploadProgress()
                          : const Text(
                              "Share Experience",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),

                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CharacterCounter extends StatelessWidget {
  final int count;

  const CharacterCounter({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '$count characters',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.deepPurple.shade300,
        ),
      ),
    );
  }
}
