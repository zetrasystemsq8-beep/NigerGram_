// lib/features/gist_hub/presentation/view/audio_detail_view.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/data/services/audio_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/widgets/report_audio_sheet.dart';
import 'package:nigergram/features/media/presentation/pages/professional_upload_page.dart';

/// Each audio's own page — title, creator attribution, use count,
/// preview playback, Use/Save/Share actions, and the list of innovation
/// posts that used this audio. Matches the plan's "Audio Page" section.
class AudioDetailView extends StatefulWidget {
  const AudioDetailView({required this.audioId, super.key});

  final String audioId;

  @override
  State<AudioDetailView> createState() => _AudioDetailViewState();
}

class _AudioDetailViewState extends State<AudioDetailView> {
  final AudioService _service = AudioService();
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPlaying = false;

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
              Center(
                child: GestureDetector(
                  onTap: () => _togglePreview(post.audioUrl),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: NGColors.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: NGColors.accent,
                      size: 48,
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
                      icon: const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
                      label: const Text('Use Audio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NGColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveAudio(post),
                      icon: Icon(Icons.bookmark_border_rounded, size: 18, color: NGColors.textPrimary),
                      label: Text('Save', style: TextStyle(color: NGColors.textPrimary)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareAudio(post),
                      icon: Icon(Icons.share_rounded, size: 18, color: NGColors.textPrimary),
                      label: Text('Share', style: TextStyle(color: NGColors.textPrimary)),
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
