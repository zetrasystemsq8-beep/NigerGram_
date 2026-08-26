// lib/features/gist_hub/presentation/view/audio_detail_view.dart
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/data/services/audio_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/report_audio_sheet.dart';
import 'package:nigergram/features/upload/presentation/view/upload_page.dart';

const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Each audio's own page — Zetra logo cover art, title, creator
/// attribution, use count, full playback controls (seek + speed),
/// Use/Save/Share/Download actions, and videos that used this audio.
class AudioDetailView extends StatefulWidget {
  const AudioDetailView({required this.audioId, super.key});

  final String audioId;

  @override
  State<AudioDetailView> createState() => _AudioDetailViewState();
}

class _AudioDetailViewState extends State<AudioDetailView> {
  static const String _logoAsset = 'assets/sounds/ic_lancher.png';

  final AudioService _service = AudioService();
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isDownloading = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;
  bool _isSeeking = false;

  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  late final Stream<AudioPostEntity?> _postStream;
  late final Stream<List<Map<String, dynamic>>> _usedInStream;

  @override
  void initState() {
    super.initState();
    _postStream = _service.getAudioPostStream(widget.audioId);
    _usedInStream = _service.getVideosUsingAudioStream(widget.audioId);

    _durationSub = _previewPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _previewPlayer.onPositionChanged.listen((p) async {
      if (!mounted || _isSeeking) return;
      setState(() => _position = p);
    });
    _completeSub = _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback(AudioPostEntity post) async {
    if (_isPlaying) {
      await _previewPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      final atStart = _position <= post.trimStart || _position >= post.trimEnd;
      await _previewPlayer.play(UrlSource(post.audioUrl));
      if (atStart) {
        await _previewPlayer.seek(post.trimStart);
      }
      await _previewPlayer.setPlaybackRate(_speed);
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _seekTo(Duration target) async {
    await _previewPlayer.seek(target);
    setState(() => _position = target);
  }

  Future<void> _changeSpeed(double speed) async {
    setState(() => _speed = speed);
    await _previewPlayer.setPlaybackRate(speed);
  }

  Future<void> _useAudio(AudioPostEntity post) async {
    final userId = AppAuth.uid;
    if (!post.canBeUsedBy(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🔒 This audio isn't available for reuse.")),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadPage(initialAudio: post),
      ),
    );
  }

  Future<void> _saveAudio(AudioPostEntity post) async {
    try {
      await _service.saveAudioForCurrentUser(post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your library')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  Future<void> _shareAudio(AudioPostEntity post) async {
    await Share.share(
      'Check out this audio on NigerGram: "${post.title}" by @${post.creatorUsername}',
      subject: post.title,
    );
  }

  Future<void> _downloadAudio(AudioPostEntity post) async {
    setState(() => _isDownloading = true);

    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        post.audioUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null) throw Exception('No data received');

      final dir = await getTemporaryDirectory();
      final safeTitle = post.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final fileName = '${safeTitle.isEmpty ? 'nigergram_audio' : safeTitle}.m4a';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Save this NigerGram audio: "${post.title}"',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _reportAudio() async {
    final reported = await ReportAudioSheet.show(context, widget.audioId);
    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — we\'ll review this report.')),
      );
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.surface,
        title: const Text('🎙️ Audio'),
        actions: [
          IconButton(
            icon: Icon(Icons.flag_outlined, color: NGColors.textMuted),
            tooltip: 'Report',
            onPressed: _reportAudio,
          ),
        ],
      ),
      body: StreamBuilder<AudioPostEntity?>(
        stream: _postStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: NGColors.accent));
          }

          final post = snapshot.data;
          if (post == null) {
            return Center(
              child: Text('This audio is no longer available.', style: TextStyle(color: NGColors.textMuted)),
            );
          }

          if (_isPlaying && _position >= post.trimEnd) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _previewPlayer.pause();
              if (mounted) setState(() => _isPlaying = false);
            });
          }

          final totalMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : post.durationSeconds * 1000;
          final sliderMax = totalMs > 0 ? totalMs.toDouble() : 1.0;
          final sliderValue = _position.inMilliseconds.clamp(0, totalMs).toDouble();
          final color = audioCategoryColor(post.category);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: NGColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(_logoAsset, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                post.title,
                textAlign: TextAlign.center,
                style: TextStyle(color: NGColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '🎙️ Original audio by @${post.creatorUsername}',
                textAlign: TextAlign.center,
                style: TextStyle(color: NGColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Used in ${post.useCount} videos',
                textAlign: TextAlign.center,
                style: TextStyle(color: NGColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Playback controls: play/pause + seek bar
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _togglePlayback(post),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: color,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: color,
                        inactiveTrackColor: NGColors.surface,
                        thumbColor: color,
                        overlayColor: color.withOpacity(0.2),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: sliderValue.clamp(0.0, sliderMax),
                        max: sliderMax,
                        onChangeStart: (_) => setState(() => _isSeeking = true),
                        onChanged: (v) => setState(() => _position = Duration(milliseconds: v.toInt())),
                        onChangeEnd: (v) async {
                          await _seekTo(Duration(milliseconds: v.toInt()));
                          setState(() => _isSeeking = false);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 64, right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position), style: TextStyle(color: NGColors.textMuted, fontSize: 11)),
                    Text(_formatDuration(_duration), style: TextStyle(color: NGColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Speed control
              Center(
                child: Wrap(
                  spacing: 8,
                  children: _speedOptions.map((speed) {
                    final selected = speed == _speed;
                    return GestureDetector(
                      onTap: () => _changeSpeed(speed),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? color : NGColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            color: selected ? Colors.white : NGColors.textMuted,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _useAudio(post),
                      icon: const Icon(Icons.mic_rounded, size: 16, color: Colors.white),
                      label: const Text('Use', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NGColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveAudio(post),
                      icon: Icon(Icons.bookmark_border_rounded, size: 16, color: NGColors.textPrimary),
                      label: Text('Save', style: TextStyle(color: NGColors.textPrimary, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareAudio(post),
                      icon: Icon(Icons.share_rounded, size: 16, color: NGColors.textPrimary),
                      label: Text('Share', style: TextStyle(color: NGColors.textPrimary, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isDownloading ? null : () => _downloadAudio(post),
                      icon: _isDownloading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: NGColors.textPrimary),
                            )
                          : Icon(Icons.download_rounded, size: 16, color: NGColors.textPrimary),
                      label: Text('Save', style: TextStyle(color: NGColors.textPrimary, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Videos using this audio',
                style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _usedInStream,
                builder: (context, usedSnapshot) {
                  if (!usedSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: NGColors.accent));
                  }

                  final videos = usedSnapshot.data!;
                  if (videos.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No videos have used this audio yet',
                          style: TextStyle(color: NGColors.textMuted, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: videos.map((v) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NGColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_outline_rounded, color: NGColors.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (v['title'] as String?)?.isNotEmpty == true ? v['title'] as String : 'Untitled',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  Text(
                                    '@${v['username'] ?? 'unknown'}',
                                    style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
