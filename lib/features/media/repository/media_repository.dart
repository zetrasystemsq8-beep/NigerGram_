// lib/features/media/repository/media_repository.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
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

  /// Chunked, resumable upload to Supabase Storage.
  /// - Breaks file into 1MB chunks.
  /// - Uses the Supabase Storage REST object endpoint with authenticated requests.
  /// - Reports progress via onProgress with bytes uploaded / total in [0..1].
  /// - Attempts resume by checking remote size via HEAD request before starting.
  /// - Retries each chunk with exponential backoff on transient failures.
  Future<String> uploadFileChunked(
    File file,
    String destinationPath, {
    void Function(double progress)? onProgress,
    String bucketName = '',
    int chunkSizeBytes = 1024 * 1024, // 1MB chunks
    int maxRetries = 3,
  }) async {
    final bucket = bucketName.isEmpty ? _bucket : bucketName;
    final totalBytes = await file.length();
    final uriBase = '${_supabase.supabaseUrl}/storage/v1/object/$bucket/$destinationPath';
    final token = _supabase.auth.currentSession?.accessToken ?? '';

    if (token.isEmpty) {
      throw Exception('Not authenticated. Cannot upload.');
    }

    final client = http.Client();
    int remoteBytes = 0;

    // Probe existing remote object size for resume capability
    Future<int> _probeRemoteSize() async {
      try {
        final headRes = await client.head(
          Uri.parse(uriBase),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));
        if (headRes.statusCode == 200 || headRes.statusCode == 206) {
          final contentLength = headRes.headers['content-length'];
          if (contentLength != null) return int.tryParse(contentLength) ?? 0;
        }
      } catch (_) {
        // Probe failed, start from 0
      }
      return 0;
    }

    try {
      // Try to get already-uploaded bytes to resume
      remoteBytes = await _probeRemoteSize();

      final rf = file.openSync(mode: FileMode.read);
      try {
        // Seek to remoteBytes if resuming
        if (remoteBytes > 0 && remoteBytes < totalBytes) {
          rf.setPositionSync(remoteBytes);
        } else if (remoteBytes >= totalBytes) {
          // Already fully uploaded
          onProgress?.call(1.0);
          return destinationPath;
        } else {
          remoteBytes = 0; // Start fresh
        }

        int uploaded = remoteBytes;
        final buffer = List<int>.filled(chunkSizeBytes, 0);

        while (uploaded < totalBytes) {
          final toRead = min(chunkSizeBytes, totalBytes - uploaded);
          final bytesRead = rf.readIntoSync(buffer, 0, toRead);
          if (bytesRead <= 0) break;

          final start = uploaded;
          final end = uploaded + bytesRead - 1;
          final chunk = Uint8List.fromList(buffer.sublist(0, bytesRead));

          // Retry logic for chunk upload
          int attempt = 0;
          bool success = false;
          while (!success && attempt < maxRetries) {
            attempt++;
            try {
              final res = await client.put(
                Uri.parse(uriBase),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/octet-stream',
                  'Content-Range': 'bytes $start-$end/$totalBytes',
                  'x-upsert': 'true',
                },
                body: chunk,
              ).timeout(const Duration(seconds: 30));

              if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
                uploaded += bytesRead;
                success = true;
                // Report real progress
                onProgress?.call(uploaded / totalBytes);
              } else if (res.statusCode >= 500 || res.statusCode == 408 || res.statusCode == 429) {
                // Retryable server errors
                if (attempt >= maxRetries) {
                  throw Exception('Chunk upload failed after $maxRetries attempts: ${res.statusCode} ${res.reasonPhrase}');
                }
                // Exponential backoff
                await Future.delayed(Duration(milliseconds: 500 * attempt));
              } else {
                // Non-retryable error
                throw Exception('Chunk upload failed: ${res.statusCode} ${res.reasonPhrase}');
              }
            } catch (e) {
              if (attempt >= maxRetries) rethrow;
              // Exponential backoff
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
        }
      } finally {
        rf.closeSync();
      }
    } finally {
      client.close();
    }

    // Final: Ensure progress shows complete and return path
    onProgress?.call(1.0);
    return destinationPath;
  }

  /// Backwards-compatible wrapper used in other callers.
  /// Routes small files to single-shot upload for speed, large files to chunked.
  Future<String> uploadFile(
    File file,
    String destinationPath, {
    void Function(double progress)? onProgress,
    String bucketName = '',
  }) async {
    final length = await file.length();
    // If file is small, reuse existing single-shot API for speed
    if (length <= 1024 * 1024 * 2) {
      onProgress?.call(0.0);
      final bytes = await file.readAsBytes();
      onProgress?.call(0.5);
      final res = await _supabase.storage.from(bucketName.isEmpty ? _bucket : bucketName).uploadBinary(
            destinationPath,
            bytes,
            fileOptions: FileOptions(cacheControl: '3600'),
          );
      onProgress?.call(1.0);
      return res.toString();
    }

    // For larger files, use chunked upload with resume and retry
    return uploadFileChunked(file, destinationPath, onProgress: onProgress, bucketName: bucketName);
  }

  /// Compresses, uploads, and deletes the original temporary file when upload completes.
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

    await uploadFile(
      compressed,
      destinationPath,
      onProgress: onUploadProgress,
      bucketName: bucketName,
    );

    // After successful upload, delete original (temporary) file from cache
    try {
      await FileUtils.deleteIfExists(originalFile);
    } catch (_) {}
  }
}
