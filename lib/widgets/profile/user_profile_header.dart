import 'package:flutter/material.dart';

import '../../screens/image_view_screen.dart';

class UserProfileHeader extends StatelessWidget {
  final String? photoUrl;
  final String userName;
  final String? bio;

  const UserProfileHeader({
    super.key,
    required this.photoUrl,
    required this.userName,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),

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
          child: CircleAvatar(
            radius: 55,
            backgroundColor: Colors.grey,
            backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                ? NetworkImage(photoUrl!)
                : null,
            child: photoUrl == null || photoUrl!.isEmpty
                ? const Icon(Icons.person, size: 40, color: Colors.white)
                : null,
          ),
        ),

        const SizedBox(height: 16),

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
