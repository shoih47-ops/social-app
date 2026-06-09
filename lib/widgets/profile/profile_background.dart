import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Default gradient shown when no cover image is set.
const profileBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff6a11cb), Color(0xff2575fc)],
);

/// Cover image and gradient only; no interactive controls.
class ProfileBackground extends StatelessWidget {
  final String coverUrl;

  const ProfileBackground({super.key, required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: _buildBackground()),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.8),
                      ],
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

  Widget _buildBackground() {
    if (_isValidImageUrl(coverUrl)) {
      return CachedNetworkImage(
        imageUrl: coverUrl,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => _gradientPlaceholder(),
      );
    }

    return _gradientPlaceholder();
  }

  Widget _gradientPlaceholder() {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: profileBackgroundGradient),
    );
  }

  bool _isValidImageUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;

    final path = uri.path.toLowerCase();
    if (path.contains('/image/upload')) return true;

    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.bmp');
  }
}
