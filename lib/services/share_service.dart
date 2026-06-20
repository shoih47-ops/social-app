import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';

class ShareService {
  static const String _appScheme = 'journa';
  static const String _appHost = 'app';
  static const String _fallbackWebHost = 'social-app-5c79b.web.app';

  static Uri postDeepLink(String postId) {
    return Uri.https(_fallbackWebHost, '/post/$postId');
  }

  static String? postIdFromInitialLink() {
    if (kIsWeb) {
      return postIdFromUri(Uri.base);
    }

    final routeName =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    return postIdFromRoute(routeName);
  }

  static String? postIdFromRoute(String routeName) {
    final trimmed = routeName.trim();
    if (trimmed.isEmpty || trimmed == '/') return null;

    final asUri = Uri.tryParse(trimmed);
    if (asUri != null && asUri.hasScheme) {
      return postIdFromUri(asUri);
    }

    return _postIdFromSegments(Uri(path: trimmed).pathSegments);
  }

  static String? postIdFromUri(Uri uri) {
    if (uri.fragment.isNotEmpty) {
      final fromFragment = _postIdFromSegments(
        Uri.parse(uri.fragment).pathSegments,
      );
      if (fromFragment != null) return fromFragment;
    }

    if (uri.scheme == _appScheme && uri.host == 'post') {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    return _postIdFromSegments(uri.pathSegments);
  }

  static Future<void> showShareOptions(BuildContext context, Post post) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Share'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await sharePost(context, post);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy Link'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await copyPostLink(context, post);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> copyPostLink(BuildContext context, Post post) async {
    final link = postDeepLink(post.id).toString();
    await Clipboard.setData(ClipboardData(text: link));

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  static Future<void> sharePost(BuildContext context, Post post) async {
    final shareText = _shareText(post);
    final subject = post.text.trim().isEmpty
        ? 'A real life moment on Journa'
        : post.text.trim();
    final origin = _shareOrigin(context);

    final previewUrl = _previewUrl(post);
    if (previewUrl != null) {
      try {
        final preview = await _previewFile(previewUrl, post);
        await Share.shareXFiles(
          [preview],
          text: shareText,
          subject: subject,
          sharePositionOrigin: origin,
        );
        return;
      } catch (_) {
        // Some hosts block direct media fetches; text sharing still works.
      }
    }

    await Share.share(
      shareText,
      subject: subject,
      sharePositionOrigin: origin,
    );
  }

  static Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return null;

    return box.localToGlobal(Offset.zero) & box.size;
  }

  static String _shareText(Post post) {
    final parts = <String>[
      if (post.text.trim().isNotEmpty) post.text.trim(),
      'Open this real life moment on Journa:',
      postDeepLink(post.id).toString(),
      if (post.type == 'video' && post.videoUrl.trim().isNotEmpty)
        post.videoUrl.trim(),
      if (post.type != 'video' && post.imageUrl.trim().isNotEmpty)
        post.imageUrl.trim(),
    ];

    return parts.join('\n\n');
  }

  static String? _previewUrl(Post post) {
    final imageUrl = post.imageUrl.trim();
    if (imageUrl.isNotEmpty) return imageUrl;

    final videoUrl = post.videoUrl.trim();
    if (videoUrl.isNotEmpty) return videoUrl;

    return null;
  }

  static Future<XFile> _previewFile(String url, Post post) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode >= 400 || response.bodyBytes.isEmpty) {
      throw Exception('Preview fetch failed');
    }

    final contentType = response.headers['content-type'] ?? _mimeForPost(post);
    final extension = _extensionForMime(contentType, post);

    return XFile.fromData(
      response.bodyBytes,
      mimeType: contentType,
      name: 'journa_${post.id}.$extension',
    );
  }

  static String _mimeForPost(Post post) {
    return post.type == 'video' ? 'video/mp4' : 'image/jpeg';
  }

  static String _extensionForMime(String mime, Post post) {
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    if (mime.contains('gif')) return 'gif';
    if (mime.startsWith('video/')) return 'mp4';
    return post.type == 'video' ? 'mp4' : 'jpg';
  }

  static String? _postIdFromSegments(List<String> segments) {
    if (segments.length >= 2 && segments[0] == 'post') {
      return segments[1].isEmpty ? null : segments[1];
    }

    return null;
  }
}
