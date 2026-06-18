// lib/features/media/repository/media_repository.dart

import 'dart:io';

import 'package:video_compress/video_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/file_utils.dart';

class MediaRepository {
  final SupabaseClient _supabase;
  final String _bucket;

  MediaRepository({SupabaseClient? supabase, String bucket = 'videos'})
      : _supabase = supabase ?? Supabase.instance.client,
        _bucket = bucket;

  /// Compresses the given [inputFile] using `video_compress` and returns the compressed File.
  /// [quality] maps to VideoQuality enum: 0=Low,1=Medium,2=High
  Future<File> compressVideo(File inputFile, int quality) async {
    await VideoCompress.setLogLevel(0);

    final VideoQuality q;
    switch (quality) {
      case 0:
        q = VideoQuality.LowQuality;
        break;
      case 2:
        q = VideoQuality.DefaultQuality; // Highest available
        break;
      case 1:
      default:
        q = VideoQuality.MediumQuality;
    }

    final MediaInfo? info =
        await VideoCompress.compressVideo(inputFile.path, quality: q);

    if (info == null || info.file == null) {
      throw Exception('Compression failed');
    }

    // Return the compressed File object
    return info.file!;
  }

  /// Uploads the [file] to Supabase Storage in a single-shot upload.
  /// Fires [onProgress] callbacks with a value in [0..1]. Note: supabase_flutter
  /// does not give byte-level progress today, so this is a best-effort wrapper.
  Future<void> uploadFile(
    File file,
    String destinationPath, {
    void Function(double progress)? onProgress,
    String bucketName = '',
  }) async {
    final bucket = bucketName.isEmpty ? _bucket : bucketName;

    // Attempt upload with retries
    const int maxRetries = 3;
    int attempt = 0;
    while (true) {
      try {
        attempt++;
        // supabase_flutter currently exposes a single-shot upload API.
        // Unfortunately it doesn't surface per-byte progress. We'll call the API
        // and emit an optimistic progress: 0.0 -> 0.9 while waiting, 1.0 on success.
        onProgress?.call(0.0);

        final bytes = await file.readAsBytes();

        // optimistic progress
        onProgress?.call(0.2);

        final res = await _supabase.storage.from(bucket).uploadBinary(
              destinationPath,
              bytes,
              fileOptions: FileOptions(cacheControl: '3600'),
            );

        // Successful upload returns a Map (or doesn't throw)
        onProgress?.call(1.0);

        return res;
      } catch (e) {
        if (attempt >= maxRetries) rethrow;
        // Backoff before retrying
        await Future.delayed(Duration(seconds: 1 * attempt));
      }
    }
  }

  /// Compresses, uploads, and deletes the original temporary file when upload completes.
  Future<void> compressUploadAndCleanup(
    File originalFile,
    String destinationPath, {
    required void Function(double compressProgress) onCompressProgress,
    required void Function(double uploadProgress) onUploadProgress,
    String bucketName = '',
  }) async {
    // Note: video_compress exposes a compression progress stream but the
    // package version used here provides only a simple API. We'll call the
    // compress API and fake a small progress flow for the demo.

    onCompressProgress(0.0);
    final compressed = await compressVideo(originalFile, 1);
    onCompressProgress(1.0);

    await uploadFile(compressed, destinationPath,
        onProgress: onUploadProgress, bucketName: bucketName);

    // After successful upload, delete original (temporary) file from cache
    try {
      await FileUtils.deleteIfExists(originalFile);
    } catch (_) {}
  }
}
