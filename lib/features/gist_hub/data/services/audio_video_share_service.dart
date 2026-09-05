// lib/features/gist_hub/data/services/audio_video_share_service.dart
//
// Generates a square MP4 video — a static Zetra logo frame paired with
// the real audio track — for sharing audio posts to platforms that
// expect video (WhatsApp Status, Instagram, etc). Uses
// flutter_quick_video_encoder, which drives Android's/iOS's own native
// hardware encoders directly — no FFmpeg.
//
// Requires the source audio to be a WAV file (raw PCM with a standard
// 44-byte header) — that's what audio_record_view.dart now records.
// Audio posts published before this feature (stored as .m4a) are not
// supported and will surface a clear error rather than fail silently.
//
// Known limitation: the video always plays back the ORIGINAL voice —
// the Deep/High voice effect is a live-playback-only effect right now
// and is not baked into the exported video.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';

class _WavData {
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;
  final Uint8List pcm;

  _WavData({
    required this.sampleRate,
    required this.numChannels,
    required this.bitsPerSample,
    required this.pcm,
  });
}

class AudioVideoShareService {
  static const String _logoAsset = 'assets/sounds/ic_lancher.png';
  static const int _videoSize = 720; // square, per user's choice
  static const int _fps = 15; // static image — low fps is enough, keeps files small

  Uint8List? _cachedLogoFrame;

  bool isWavUrl(String url) => url.toLowerCase().contains('.wav');

  Future<Uint8List> _downloadBytes(String url) async {
    final dio = Dio();
    final response = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) throw Exception('Could not download audio.');
    return Uint8List.fromList(data);
  }

  _WavData _parseWav(Uint8List bytes) {
    if (bytes.length < 44) {
      throw Exception('Audio file is too short or not a valid WAV file.');
    }
    final bd = bytes.buffer.asByteData();
    final numChannels = bd.getUint16(22, Endian.little);
    final sampleRate = bd.getUint32(24, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);

    // Find the 'data' chunk rather than assuming it starts at byte 44 —
    // some WAV writers insert extra chunks before it.
    int dataStart = 44;
    for (int i = 12; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 && bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
        dataStart = i + 8;
        break;
      }
    }

    return _WavData(
      sampleRate: sampleRate,
      numChannels: numChannels,
      bitsPerSample: bitsPerSample,
      pcm: bytes.sublist(dataStart),
    );
  }

  Uint8List _sliceTrim(_WavData wav, int trimStartMs, int trimEndMs) {
    final bytesPerSample = wav.bitsPerSample ~/ 8;
    final bytesPerFrame = bytesPerSample * wav.numChannels;

    int startByte = ((trimStartMs / 1000) * wav.sampleRate).round() * bytesPerFrame;
    int endByte = ((trimEndMs / 1000) * wav.sampleRate).round() * bytesPerFrame;

    startByte = startByte.clamp(0, wav.pcm.length);
    endByte = endByte.clamp(startByte, wav.pcm.length);

    return wav.pcm.sublist(startByte, endByte);
  }

  Future<Uint8List> _renderLogoFrameOnce() async {
    if (_cachedLogoFrame != null) return _cachedLogoFrame!;

    final assetData = await rootBundle.load(_logoAsset);
    final assetBytes = assetData.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(assetBytes);
    final frameInfo = await codec.getNextFrame();
    final logoImage = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, _videoSize.toDouble(), _videoSize.toDouble()),
    );

    final bgPaint = ui.Paint()..color = const ui.Color(0xFF0B0B0F);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, _videoSize.toDouble(), _videoSize.toDouble()), bgPaint);

    const paddingFraction = 0.18;
    final maxDim = _videoSize * (1 - paddingFraction * 2);
    final largerSide = logoImage.width > logoImage.height ? logoImage.width : logoImage.height;
    final scale = maxDim / largerSide;
    final drawWidth = logoImage.width * scale;
    final drawHeight = logoImage.height * scale;
    final dx = (_videoSize - drawWidth) / 2;
    final dy = (_videoSize - drawHeight) / 2;

    final imgPaint = ui.Paint()..filterQuality = ui.FilterQuality.high;
    canvas.drawImageRect(
      logoImage,
      ui.Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
      ui.Rect.fromLTWH(dx, dy, drawWidth, drawHeight),
      imgPaint,
    );

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(_videoSize, _videoSize);
    final rgbaData = await finalImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgbaData == null) throw Exception('Failed to render the logo frame.');

    _cachedLogoFrame = rgbaData.buffer.asUint8List();
    return _cachedLogoFrame!;
  }

  /// Generates the video and returns the local file path of the
  /// finished MP4, ready to hand to Share.shareXFiles.
  Future<String> generateShareVideo(AudioPostEntity post) async {
    if (!isWavUrl(post.audioUrl)) {
      throw Exception(
        'This audio was posted before video-sharing was added and can\'t be turned into a video yet. Newly posted audio supports this.',
      );
    }

    final rawBytes = await _downloadBytes(post.audioUrl);
    final wav = _parseWav(rawBytes);
    final trimmedPcm = _sliceTrim(wav, post.trimStartMs, post.trimEndMs);

    final logoFrame = await _renderLogoFrameOnce();

    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/nigergram_share_${DateTime.now().millisecondsSinceEpoch}.mp4';

    await FlutterQuickVideoEncoder.setup(
      width: _videoSize,
      height: _videoSize,
      fps: _fps,
      videoBitrate: 2000000,
      audioChannels: wav.numChannels,
      audioBitrate: 96000,
      sampleRate: wav.sampleRate,
      filepath: outputPath,
    );

    final bytesPerSample = wav.bitsPerSample ~/ 8;
    final bytesPerAudioFrame = ((wav.sampleRate * wav.numChannels * bytesPerSample) / _fps).round();

    final durationMs = post.trimEndMs - post.trimStartMs;
    final totalFrames = ((durationMs / 1000) * _fps).ceil().clamp(1, 1 << 30);

    int audioOffset = 0;
    for (int i = 0; i < totalFrames; i++) {
      await FlutterQuickVideoEncoder.appendVideoFrame(logoFrame);

      final remaining = trimmedPcm.length - audioOffset;
      final chunkSize = remaining >= bytesPerAudioFrame ? bytesPerAudioFrame : (remaining > 0 ? remaining : 0);

      Uint8List audioChunk;
      if (chunkSize == bytesPerAudioFrame) {
        audioChunk = trimmedPcm.sublist(audioOffset, audioOffset + chunkSize);
      } else {
        // Pad the final, shorter chunk with silence so audio/video stay
        // in sync right up to the last frame.
        audioChunk = Uint8List(bytesPerAudioFrame);
        if (chunkSize > 0) {
          audioChunk.setRange(0, chunkSize, trimmedPcm.sublist(audioOffset, audioOffset + chunkSize));
        }
      }
      audioOffset += chunkSize;

      await FlutterQuickVideoEncoder.appendAudioFrame(audioChunk);
    }

    await FlutterQuickVideoEncoder.finish();
    return outputPath;
  }
}
