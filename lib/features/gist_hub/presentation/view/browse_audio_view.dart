// lib/features/gist_hub/presentation/view/browse_audio_view.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/gist_hub/data/services/audio_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/view/audio_record_view.dart';
import 'package:nigergram/features/gist_hub/presentation/view/audio_detail_view.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'trending';
  late Stream<List<AudioPostEntity>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _service.getAudioFeedStream(filter: _selectedFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: NGColors.textPrimary),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search audio by title or creator',
                hintStyle: TextStyle(color: NGColors.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: NGColors.textMuted),
                filled: true,
                fillColor: NGColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
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
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<AudioPostEntity>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Can\'t load audio right now', style: TextStyle(color: NGColors.textSecondary)),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: NGColors.accent));
                }

                var posts = snapshot.data!;
                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  posts = posts
                      .where((p) => p.title.toLowerCase().contains(query) || p.creatorUsername.toLowerCase().contains(query))
                      .toList();
                }

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_none_rounded, color: NGColors.textMuted, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          query.isNotEmpty ? 'No audio matches "$query"' : 'No audio here yet',
                          style: TextStyle(color: NGColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          query.isNotEmpty ? 'Try a different search' : 'Be the first to record something',
                          style: TextStyle(color: NGColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final color = audioCategoryColor(post.category);

                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AudioDetailView(audioId: post.id)),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: NGColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(audioCategoryEmoji(post.category), style: const TextStyle(fontSize: 20)),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: NGColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatDuration(post.durationSeconds),
                                    style: TextStyle(color: NGColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14, height: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '@${post.creatorUsername}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.graphic_eq_rounded, size: 13, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  '${post.useCount} used',
                                  style: TextStyle(color: NGColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
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
