import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:video_compress/video_compress.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'ddaducxab';
  static const String _uploadPreset = 'social_app';

  static Future<String> uploadImage(
    File imageFile, {
    void Function(double progress)? onProgress,
  }) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(
      await _multipartFileWithProgress(imageFile, onProgress: onProgress),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final result = jsonDecode(responseData) as Map<String, dynamic>;

    if (response.statusCode >= 400 || result['secure_url'] == null) {
      throw Exception(result['error']?['message'] ?? 'Image upload failed');
    }

    return result['secure_url'] as String;
  }

  /// Uploads a video to Cloudinary. Applies auto compression for large files.
  static Future<String> uploadVideo(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
    );

    // Compress video locally before upload to improve buffering and bandwidth.
    try {
      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      final compressedPath = info?.path ?? videoFile.path;
      final compressedFile = File(compressedPath);

      final fileSize = await compressedFile.length();

      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['resource_type'] = 'video';

      // Ask Cloudinary to perform adaptive quality if file still large.
      if (fileSize > 15 * 1024 * 1024) {
        request.fields['quality'] = 'auto:eco';
        request.fields['video_codec'] = 'auto';
      } else {
        request.fields['quality'] = 'auto';
      }

      request.files.add(
        await _multipartFileWithProgress(
          compressedFile,
          onProgress: onProgress,
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final result = jsonDecode(responseData) as Map<String, dynamic>;

      if (response.statusCode >= 400 || result['secure_url'] == null) {
        throw Exception(result['error']?['message'] ?? 'Video upload failed');
      }

      return result['secure_url'] as String;
    } finally {
      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}
    }
  }

  /// Uploads a video from bytes. Used by Flutter Web where dart:io File APIs
  /// and native video compression are unavailable.
  static Future<String> uploadVideoBytes(
    List<int> bytes, {
    String filename = 'video.mp4',
    void Function(double progress)? onProgress,
  }) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
    );

    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['resource_type'] = 'video';
    request.fields['quality'] = 'auto';
    request.files.add(
      _multipartBytesWithProgress(
        bytes,
        filename: filename,
        onProgress: onProgress,
      ),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final result = jsonDecode(responseData) as Map<String, dynamic>;

    if (response.statusCode >= 400 || result['secure_url'] == null) {
      throw Exception(result['error']?['message'] ?? 'Video upload failed');
    }

    return result['secure_url'] as String;
  }

  /// Upload bytes as an image by writing to a temp file and reusing uploadImage.
  static Future<String> uploadBytesAsImage(
    List<int> bytes, {
    void Function(double progress)? onProgress,
  }) async {
    final tmp = await Directory.systemTemp.createTemp('thumb');
    final file = File('${tmp.path}/thumb.jpg');
    await file.writeAsBytes(bytes);
    final url = await uploadImage(file, onProgress: onProgress);
    try {
      await file.delete();
      await tmp.delete();
    } catch (_) {}
    return url;
  }

  static Future<String> uploadImageBytes(
    List<int> bytes, {
    String filename = 'image.jpg',
    void Function(double progress)? onProgress,
  }) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(
      _multipartBytesWithProgress(
        bytes,
        filename: filename,
        onProgress: onProgress,
      ),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final result = jsonDecode(responseData) as Map<String, dynamic>;

    if (response.statusCode >= 400 || result['secure_url'] == null) {
      throw Exception(result['error']?['message'] ?? 'Image upload failed');
    }

    return result['secure_url'] as String;
  }

  static Future<http.MultipartFile> _multipartFileWithProgress(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final length = await file.length();
    var uploaded = 0;

    final stream = file.openRead().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          uploaded += data.length;
          if (length > 0) {
            onProgress?.call((uploaded / length).clamp(0, 1).toDouble());
          }
          sink.add(data);
        },
      ),
    );

    return http.MultipartFile(
      'file',
      stream,
      length,
      filename: file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'upload',
    );
  }

  static http.MultipartFile _multipartBytesWithProgress(
    List<int> bytes, {
    required String filename,
    void Function(double progress)? onProgress,
  }) {
    onProgress?.call(1);
    return http.MultipartFile.fromBytes('file', bytes, filename: filename);
  }
}
