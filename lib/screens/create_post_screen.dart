import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/cloudinary_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../services/post_service.dart';
import 'dart:async';

class CreatePostScreen extends StatefulWidget {
  final VoidCallback? onPostSuccess;

  const CreatePostScreen({super.key, this.onPostSuccess});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final textController = TextEditingController();

  File? _selectedImage;
  File? _selectedVideo;
  bool _isUploading = false;
  // reserved for future upload progress

  bool isFocused = false;

  FocusNode focusNode = FocusNode();

  Future<void> _pickImageFrom(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1080,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickVideoFrom(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: source);

    if (pickedFile != null) {
      final file = File(pickedFile.path);

      // Temporarily load the video to check duration
      final tempController = VideoPlayerController.file(file);
      try {
        await tempController.initialize();
        final duration = tempController.value.duration;
        if (duration > const Duration(seconds: 30)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video must be 30 seconds or shorter'),
            ),
          );
          await tempController.dispose();
          return;
        }

        setState(() {
          _selectedVideo = file;
          _selectedImage = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to read video: $e')));
      } finally {
        try {
          await tempController.dispose();
        } catch (_) {}
      }
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
    loadUser();

    focusNode.addListener(() {
      setState(() {
        isFocused = focusNode.hasFocus;
      });
    });
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
                        hintText: "Share your day...",
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

                SizedBox(height: 24),

                _selectedImage != null
                    ? Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedImage!,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,

                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),

                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },

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
                      )
                    : _selectedImage != null
                    ? Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedImage!,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
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
                      )
                    : _selectedVideo != null
                    ? Stack(
                        children: [
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: Colors.black,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedVideo = null;
                                });
                              },
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
                      )
                    : SizedBox(),

                Row(
                  children: [
                    // Camera
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickFromCameraChoice(),
                        child: Container(
                          height: 115,

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),

                            borderRadius: BorderRadius.circular(28),

                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                                size: 34,
                                color: Colors.deepPurple,
                              ),

                              SizedBox(height: 10),

                              Text(
                                "Camera",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              SizedBox(height: 4),

                              Text(
                                "Capture now",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 14),

                    // Gallery (images)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await _pickImageFrom(ImageSource.gallery);
                        },
                        child: Container(
                          height: 115,

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),

                            borderRadius: BorderRadius.circular(28),

                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 34,
                                color: Colors.deepPurple,
                              ),

                              SizedBox(height: 10),

                              Text(
                                "Gallery",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              SizedBox(height: 4),

                              Text(
                                "Choose image",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 14),

                    // Video (separate button)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await _pickVideoFrom(ImageSource.gallery);
                        },
                        child: Container(
                          height: 115,

                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),

                            borderRadius: BorderRadius.circular(28),

                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam,
                                size: 34,
                                color: Colors.deepPurple,
                              ),

                              SizedBox(height: 10),

                              Text(
                                "Video",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              SizedBox(height: 4),

                              Text(
                                "Choose clip",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    });

                    try {
                      String imageUrl = '';
                      String videoUrl = '';
                      String type = 'image';

                      if (_selectedVideo != null) {
                        type = 'video';

                        // generate thumbnail bytes
                        final thumbData = await VideoThumbnail.thumbnailData(
                          video: _selectedVideo!.path,
                          imageFormat: ImageFormat.JPEG,
                          maxWidth: 720,
                          quality: 75,
                        );

                        String thumbUrl = '';
                        if (thumbData != null) {
                          thumbUrl = await CloudinaryService.uploadBytesAsImage(
                            thumbData,
                          );
                        }

                        // upload compressed video (CloudinaryService compresses internally)
                        videoUrl = await CloudinaryService.uploadVideo(
                          _selectedVideo!,
                        );

                        imageUrl =
                            thumbUrl; // store thumbnail as imageUrl for feed
                      } else if (_selectedImage != null) {
                        imageUrl = await CloudinaryService.uploadImage(
                          _selectedImage!,
                        );
                        type = 'image';
                      }

                      await PostService.addPost(
                        text: textController.text,
                        imageUrl: imageUrl,
                        videoUrl: videoUrl,
                        type: type,
                      );

                      textController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _selectedImage = null;
                        _selectedVideo = null;
                        _isUploading = false;
                      });

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text("Posted")));
                      widget.onPostSuccess?.call();
                    } catch (e) {
                      setState(() {
                        _isUploading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Upload failed: $e')),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
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
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),

                                SizedBox(height: 6),
                                Text(
                                  "Sharing...",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              "Post",
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
