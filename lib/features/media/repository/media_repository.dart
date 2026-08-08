// lib/features/media/repository/media_repository.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/file_utils.dart';

class MediaRepository {
  final SupabaseClient _supabase;

  MediaRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static const String _workerBaseUrl = 'https://zetra-media.debugging558.workers.dev';

  /// The playable/download URL for a stored object key. Firestore only
  /// ever stores the key (e.g. "videos/abc123.mp4") — this builds the
  /// real URL at read time, routed through the Cloudflare Worker so
  /// the B2 bucket can stay private.
  static String publicUrlFor(String objectKey) {
    return '$_workerBaseUrl/$objectKey';
  }

  /// Generates a safe, unique object key — not just the raw filename —
  /// scoped to the current user (required by the Worker's auth check).
  static String generateVideoKey(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random.secure().nextInt(999999).toString().padLeft(6, '0');
    return 'videos/${userId}_${timestamp}_$randomSuffix.mp4';
  }

  Future<File> compressVideo(File inputFile, int quality) async {
    await VideoCompress.setLogLevel(0);

    final VideoQuality q;
    switch (quality) {
      case 0:
        q = VideoQuality.LowQuality;
        break;
      case 2:
        q = VideoQuality.DefaultQuality;
        break;
      case 1:
      default:
        q = VideoQuality.MediumQuality;
    }

    final MediaInfo? info = await VideoCompress.compressVideo(inputFile.path, quality: q);

    if (info == null || info.file == null) {
      throw Exception('Compression failed');
    }

    return info.file!;
  }

  /// Uploads [file] to B2 via the Cloudflare Worker. The Worker validates
  /// the Supabase session and signs the actual B2 request — no storage
  /// credentials ever exist on the phone.
  Future<String> uploadFile(
    File file,
    String objectKey, {
    void Function(double progress)? onProgress,
    String contentType = 'video/mp4',
  }) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Not authenticated. Cannot upload.');
    }

    final bytes = await file.readAsBytes();
    final totalBytes = bytes.length;

    final uri = Uri.parse(MediaRepository.publicUrlFor(objectKey));
    final request = http.StreamedRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = contentType;
    request.contentLength = totalBytes;

    const chunkSize = 256 * 1024;
    int sent = 0;

    unawaited(() async {
      for (var offset = 0; offset < totalBytes; offset += chunkSize) {
        final end = (offset + chunkSize < totalBytes) ? offset + chunkSize : totalBytes;
        request.sink.add(bytes.sublist(offset, end));
        sent = end;
        onProgress?.call(sent / totalBytes);
      }
      await request.sink.close();
    }());

    final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} ${response.body}');
    }

    onProgress?.call(1.0);
    return objectKey;
  }

  /// Compresses, uploads, and deletes the original temporary file when upload completes.
  /// Returns the B2 object key — Firestore stores only this, never a full URL.
  Future<String> compressUploadAndCleanup(
    File originalFile,
    String objectKey, {
    required void Function(double compressProgress) onCompressProgress,
    required void Function(double uploadProgress) onUploadProgress,
    int quality = 1,
  }) async {
    onCompressProgress(0.0);
    final compressed = await compressVideo(originalFile, quality);
    onCompressProgress(1.0);

    final uploadedKey = await uploadFile(
      compressed,
      objectKey,
      onProgress: onUploadProgress,
    );

    try {
      await FileUtils.deleteIfExists(originalFile);
    } catch (_) {}

    return uploadedKey;
  }
}
