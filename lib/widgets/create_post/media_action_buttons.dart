part of '../../screens/create_post_screen.dart';

class MediaActionButtons extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onVideoTap;

  const MediaActionButtons({
    super.key,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MediaActionButton(
            icon: Icons.photo_camera_outlined,
            title: 'Camera',
            subtitle: 'Capture now',
            onTap: onCameraTap,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _MediaActionButton(
            icon: Icons.image_outlined,
            title: 'Gallery',
            subtitle: 'Choose image',
            onTap: onGalleryTap,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _MediaActionButton(
            icon: Icons.videocam,
            title: 'Video',
            subtitle: 'Choose clip',
            onTap: onVideoTap,
          ),
        ),
      ],
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MediaActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.35),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.deepPurple),
            SizedBox(height: 7),
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
