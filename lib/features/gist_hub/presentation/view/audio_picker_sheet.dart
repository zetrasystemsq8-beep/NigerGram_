// lib/features/gist_hub/presentation/view/audio_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/app_auth.dart';
import 'package:nigergram/features/gist_hub/data/services/audio_service.dart';
import 'package:nigergram/features/gist_hub/domain/entities/audio_post_entity.dart';
import 'package:nigergram/features/gist_hub/presentation/view/browse_audio_view.dart' show audioDiscoveryFilters;

/// Bottom sheet for picking an existing audio post to attach to a new
/// video/innovation post. Pops with the selected AudioPostEntity, or
/// null if dismissed without picking one.
class AudioPickerSheet extends StatefulWidget {
  const AudioPickerSheet({super.key});

  @override
  State<AudioPickerSheet> createState() => _AudioPickerSheetState();

  static Future<AudioPostEntity?> show(BuildContext context) {
    return showModalBottomSheet<AudioPostEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AudioPickerSheet(),
    );
  }
}

class _AudioPickerSheetState extends State<AudioPickerSheet> {
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

  @override
  Widget build(BuildContext context) {
    final userId = AppAuth.uid;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: NGColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '🎙️ Use Audio',
                  style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: NGColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: NGColors.textPrimary),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by title or creator',
                hintStyle: TextStyle(color: NGColors.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: NGColors.textMuted),
                filled: true,
                fillColor: NGColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: audioDiscoveryFilters.length,
              itemBuilder: (context, index) {
                final filter = audioDiscoveryFilters[index];
                final selected = filter['key'] == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _changeFilter(filter['key']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? NGColors.accent : NGColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          filter['label']!,
                          style: TextStyle(
                            color: selected ? Colors.white : NGColors.textPrimary,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AudioPostEntity>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: NGColors.accent));
                }

                final query = _searchController.text.trim().toLowerCase();
                var posts = snapshot.data!;
                if (query.isNotEmpty) {
                  posts = posts
                      .where((p) => p.title.toLowerCase().contains(query) || p.creatorUsername.toLowerCase().contains(query))
                      .toList();
                }

                if (posts.isEmpty) {
                  return Center(
                    child: Text('No audio found', style: TextStyle(color: NGColors.textMuted)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final canUse = post.canBeUsedBy(userId);

                    return Opacity(
                      opacity: canUse ? 1.0 : 0.4,
                      child: ListTile(
                        onTap: canUse
                            ? () => Navigator.of(context).pop(post)
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("🔒 This audio isn't available for reuse.")),
                                );
                              },
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: NGColors.accent.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(Icons.graphic_eq_rounded, color: NGColors.accent),
                        ),
                        title: Text(
                          post.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: NGColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          '@${post.creatorUsername} · Used in ${post.useCount} videos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: NGColors.textMuted, fontSize: 12),
                        ),
                        trailing: canUse ? null : const Icon(Icons.lock_outline_rounded, size: 16),
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
