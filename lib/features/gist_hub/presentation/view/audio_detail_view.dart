// lib/features/gist_hub/presentation/view/audio_detail_view.dart
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/data/services/audio_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/report_audio_sheet.dart';
import 'package:nigergram/features/media/presentation/pages/professional_upload_page.dart';

/// Each audio's own page — Zetra logo cover art, title, creator
/// attribution, use count, preview playback, Use/Save/Share/Download
/// actions, and the list of innovation posts that used this audio.
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

  late final Stream<AudioPostEntity?> _postStream;
  late final Stream<List<Map<String, dynamic>>> _usedInStream;

  @override
  void initState() {
    super.initState();
    _postStream = _service.getAudioPostStream(widget.audioId);
    _usedInStream = _service.getVideosUsingAudioStream(widget.audioId);

    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(String audioUrl) async {
    if (_isPlaying) {
      await _previewPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _previewPlayer.play(UrlSource(audioUrl));
      setState(() => _isPlaying = true);
    }
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
        builder: (_) => ProfessionalUploadPage(initialAudio: post),
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

  /// Downloads the raw audio file straight to the phone's Downloads
  /// folder. Note: on Android 11+, writing directly into the public
  /// Downloads folder without scoped-storage APIs can be blocked on
  /// some devices/OEM skins depending on permission grants — if this
  /// silently fails to appear in Downloads on a given phone, that's
  /// the likely cause, and the proper long-term fix is a dedicated
  /// downloads/media-store package rather than a raw file write.
  Future<void> _downloadAudio(AudioPostEntity post) async {
    setState(() => _isDownloading = true);

    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      final dio = Dio();
      final response = await dio.get<List<int>>(
        post.audioUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null) throw Exception('No data received');

      Directory saveDir;
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (Platform.isAndroid && await publicDownloads.exists()) {
        saveDir = publicDownloads;
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final safeTitle = post.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final fileName = '${safeTitle.isEmpty ? 'nigergram_audio' : safeTitle}_${post.id}.m4a';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as "$fileName"')),
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

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
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

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Zetra logo cover art — replaces what used to be a blank
              // area with no visual identity for the audio.
              Center(
                child: Container(
                  width: 160,
                  height: 160,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: NGColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NGColors.accent.withOpacity(0.2)),
                  ),
                  child: Image.asset(
                    _logoAsset,
                    fit: BoxFit.contain,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => _togglePreview(post.audioUrl),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: NGColors.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: NGColors.accent,
                      size: 34,
                    ),
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
                'Used in ${post.useCount} videos · ${_formatDuration(post.durationSeconds)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: NGColors.textMuted, fontSize: 12),
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
