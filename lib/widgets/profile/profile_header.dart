import 'package:flutter/material.dart';

import '../../screens/image_view_screen.dart';

class ProfileHeader extends StatelessWidget {
  final String? photoUrl;
  final String userName;
  final String? bio;
  final VoidCallback onPickImage;

  const ProfileHeader({
    super.key,
    required this.photoUrl,
    required this.userName,
    required this.bio,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),

        /// PROFILE IMAGE
        GestureDetector(
          onTap: () {
            if (photoUrl != null && photoUrl!.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewScreen(imageUrl: photoUrl!),
                ),
              );
            }
          },
          onLongPress: onPickImage,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey,
                backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                    ? NetworkImage(photoUrl!)
                    : null,
                child: photoUrl == null || photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onPickImage,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        /// USERNAME
        Text(
          userName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        if (bio?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),

          /// BIO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 15),
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}
