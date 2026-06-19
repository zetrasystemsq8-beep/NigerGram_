// lib/features/media/repository/media_repository.dart

import 'dart:io';
import 'dart:math';

import 'package:video_compress/video_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

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

    final MediaInfo? info = await VideoCompress.compressVideo(inputFile.path, quality: q);

    if (info == null || info.file == null) {
      throw Exception('Compression failed');
    }

    // Return the compressed File object
    return info.file!;
  }

  /// Chunked upload using Supabase Storage REST PUTs with Content-Range headers when supported.
  /// This breaks file into chunks (default ~1.5MB) and uploads sequentially with retries.
  Future<String> uploadFile(
    File file,
    String destinationPath, {
    void Function(double progress)? onProgress,
    int chunkSize = 1500 * 1024,
    String bucketName = '',
  }) async {
    final bucket = bucketName.isEmpty ? _bucket : bucketName;
    final int totalBytes = await file.length();

    final uri = Uri.parse('${_supabase.url}/storage/v1/object/$bucket/$destinationPath');

    final RandomAccessFile raf = await file.open();
    int uploaded = 0;
    try {
      while (uploaded < totalBytes) {
        final remaining = totalBytes - uploaded;
        final thisChunkSize = min(chunkSize, remaining);
        final buffer = await raf.read(thisChunkSize);

        final from = uploaded;
        final to = uploaded + buffer.length - 1;

        final headers = <String, String>{
          'x-upsert': 'true',
          'Content-Type': lookupMimeType(file.path) ?? 'application/octet-stream',
          'Content-Range': 'bytes $from-$to/$totalBytes',
        };

        // Add authorization header when available (anonymous may work if rules permit)
        final token = _supabase.auth.currentSession?.accessToken;
        if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

        int attempt = 0;
        const maxAttempts = 4;
        while (attempt < maxAttempts) {
          attempt++;
          try {
            final res = await http.put(uri, headers: headers, body: buffer).timeout(const Duration(seconds: 30));
            if (res.statusCode >= 200 && res.statusCode < 300) {
              uploaded += buffer.length;
              onProgress?.call(uploaded / totalBytes);
              break;
            } else {
              if (attempt >= maxAttempts) {
                throw Exception('Chunk upload failed: ${res.statusCode} ${res.body}');
              }
              await Future.delayed(Duration(milliseconds: 250 * attempt));
            }
          } catch (e) {
            if (attempt >= maxAttempts) rethrow;
            await Future.delayed(Duration(milliseconds: 250 * attempt));
          }
        }
      }

      // Return a public URL for the uploaded object (if bucket/public rules permit)
      final publicUrl = _supabase.storage.from(bucket).getPublicUrl(destinationPath).publicURL;
      onProgress?.call(1.0);
      return publicUrl;
    } finally {
      await raf.close();
    }
  }

  /// Compresses, uploads, and deletes the original temporary file when upload completes.
  /// [quality] is forwarded to the compression step (0=Low,1=Medium,2=High).
  Future<void> compressUploadAndCleanup(
    File originalFile,
    String destinationPath, {
    required void Function(double compressProgress) onCompressProgress,
    required void Function(double uploadProgress) onUploadProgress,
    String bucketName = '',
    int quality = 1,
  }) async {
    onCompressProgress(0.0);
    final compressed = await compressVideo(originalFile, quality);
    onCompressProgress(1.0);

    try {
      await uploadFile(
        compressed,
        destinationPath,
        onProgress: (p) => uploadProgress(p),
        chunkSize: 1500 * 1024,
        bucketName: bucketName,
      );
    } finally {
      try {
        await FileUtils.deleteIfExists(compressed);
      } catch (_) {}
    }
  }
}
