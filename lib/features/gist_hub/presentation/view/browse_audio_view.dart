// lib/features/gist_hub/presentation/view/browse_audio_view.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/audio_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/view/audio_record_view.dart';

const List<Map<String, String>> audioDiscoveryFilters = [
  {'key': 'trending', 'label': '🔥 Trending'},
  {'key': 'rising', 'label': '🚀 Rising'},
  {'key': 'idea', 'label': '💡 Ideas'},
  {'key': 'educational', 'label': '📚 Learn'},
  {'key': 'motivation', 'label': '🎯 Motivation'},
  {'key': 'original', 'label': '🎙️ Original'},
];

class BrowseAudioView extends StatefulWidget {
  const BrowseAudioView({super.key});

  @override
  State<BrowseAudioView> createState() => _BrowseAudioViewState();
}

class _BrowseAudioViewState extends State<BrowseAudioView> {
  final AudioService _service = AudioService();
  String _selectedFilter = 'trending';
  late Stream<List<AudioPostEntity>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _service.getAudioFeedStream(filter: _selectedFilter);
  }

  void _changeFilter(String key) {
    if (key == _selectedFilter) return;
    setState(() {
      _selectedFilter = key;
      _stream = _service.getAudioFeedStream(filter: key);
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: FloatingActionButton(
          backgroundColor: NGColors.accent,
          elevation: 8,
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
          onPressed: () async {
            final published = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (context) => const AudioRecordView()),
            );
            if (published == true) {
              setState(() {
                _stream = _service.getAudioFeedStream(filter: _selectedFilter);
              });
            }
          },
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: audioDiscoveryFilters.length,
              itemBuilder: (context, index) {
                final filter = audioDiscoveryFilters[index];
                final selected = filter['key'] == _selectedFilter;
                return GestureDetector(
                  onTap: () => _changeFilter(filter['key']!),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? NGColors.accent : NGColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NGColors.accent.withOpacity(selected ? 0 : 0.2)),
                    ),
                    child: Center(
                      child: Text(
                        filter['label']!,
                        style: TextStyle(
                          color: selected ? Colors.white : NGColors.textPrimary,
                          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AudioPostEntity>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Can\'t load audio right now',
                      style: TextStyle(color: NGColors.textSecondary),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: NGColors.accent));
                }

                final posts = snapshot.data!;

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_none_rounded, color: NGColors.textMuted, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          'No audio here yet',
                          style: TextStyle(color: NGColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to record something',
                          style: TextStyle(color: NGColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NGColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: NGColors.accent.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.graphic_eq_rounded, color: NGColors.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '🎙️ Original audio by @${post.creatorUsername} · Used in ${post.useCount} videos',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDuration(post.durationSeconds),
                            style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
