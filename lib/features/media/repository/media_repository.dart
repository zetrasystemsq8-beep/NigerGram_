// lib/features/media/repository/media_repository.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:video_compress/video_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/file_utils.dart';

class MediaRepository {
  final SupabaseClient _supabase;

  MediaRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Public read URL for an object stored in B2, given only its object
  /// key (e.g. "videos/abc123.mp4"). Firestore should only ever store
  /// the key — this function builds the full URL at read time, per the
  /// "never duplicate full URLs" rule.
  ///
  /// NOTE: bucket is currently Private, so this raw URL will only work
  /// once the bucket is made public OR once a Cloudflare-fronted public
  /// domain is set up in front of it. Update this single function when
  /// that's decided — nothing else in the app needs to change.
  static String publicUrlFor(String objectKey) {
    const endpoint = 'zetra-storage-q8.s3.us-east-005.backblazeb2.com';
    return 'https://$endpoint/$objectKey';
  }

  /// Compresses the given [inputFile] using `video_compress` and returns the compressed File.
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

  /// Asks our Supabase Edge Function for a short-lived, single-file
  /// presigned upload URL. The real B2 key never touches this app —
  /// it lives only in the Edge Function's environment.
  Future<Map<String, dynamic>> _requestUploadUrl(String objectKey, String contentType) async {
    final response = await _supabase.functions.invoke(
      'get-upload-url',
      body: {
        'objectKey': objectKey,
        'contentType': contentType,
      },
    );

    if (response.status != 200) {
      throw Exception('Could not get upload URL: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Uploads [file] directly to B2 using a presigned URL obtained from
  /// our Edge Function. Reports progress via onProgress in [0..1].
  Future<String> uploadFile(
    File file,
    String objectKey, {
    void Function(double progress)? onProgress,
    String contentType = 'video/mp4',
  }) async {
    onProgress?.call(0.0);

    final urlInfo = await _requestUploadUrl(objectKey, contentType);
    final uploadUrl = urlInfo['uploadUrl'] as String;

    onProgress?.call(0.1);

    final bytes = await file.readAsBytes();
    final totalBytes = bytes.length;

    // A plain PUT with a presigned URL doesn't give us native progress
    // callbacks the way multipart does, so we do a manual streamed PUT
    // and estimate progress off bytes sent.
    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
    request.headers['Content-Type'] = contentType;
    request.contentLength = totalBytes;

    const chunkSize = 256 * 1024; // 256KB chunks for progress granularity
    int sent = 0;

    unawaited(() async {
      for (var offset = 0; offset < totalBytes; offset += chunkSize) {
        final end = (offset + chunkSize < totalBytes) ? offset + chunkSize : totalBytes;
        request.sink.add(bytes.sublist(offset, end));
        sent = end;
        onProgress?.call(0.1 + (sent / totalBytes) * 0.9);
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
  /// Returns the B2 object key (NOT a full URL) — matches the
  /// "store only the object key" rule from the architecture doc.
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
