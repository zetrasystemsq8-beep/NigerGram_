// lib/features/video_feed/presentation/view/discover_feed_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';

class DiscoverFeedView extends StatefulWidget {
  final String? tag; // ✅ ADD THIS

  const DiscoverFeedView({super.key, this.tag}); // ✅ ADD THIS

  @override
  State<DiscoverFeedView> createState() => _DiscoverFeedViewState();
}

class _DiscoverFeedViewState extends State<DiscoverFeedView> {
  List<VideoEntity> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(20);

      // ✅ If tag is provided, filter by it
      if (widget.tag != null && widget.tag!.isNotEmpty) {
        query = query.where('tags', arrayContains: widget.tag);
      }

      final snapshot = await query.get();

      final videos = snapshot.docs.map((doc) {
        final data = doc.data();
        return VideoEntity(
          id: doc.id,
          videoUrl: data['videoUrl'] ?? '',
          creatorId: data['creatorId'] ?? '',
          username: data['username'] ?? '',
          profileImageUrl: data['profileImageUrl'],
          description: data['description'] ?? '',
          soundName: data['soundName'],
          likeCount: data['likeCount'] ?? 0,
          commentCount: data['commentCount'] ?? 0,
          shareCount: data['shareCount'] ?? 0,
          viewCount: data['viewCount'] ?? 0,
          loopCount: data['loopCount'] ?? 0,
          isLiked: false,
          isBookmarked: false,
          isFollowing: false,
          isVerified: data['isVerified'] ?? false,
          isPremium: data['isPremium'] ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading videos: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NGColors.background,
      appBar: AppBar(
        backgroundColor: NGColors.background,
        title: Text(
          widget.tag != null ? 'Discover #${widget.tag}' : 'Discover',
          style: TextStyle(
            color: NGColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: NGColors.accent,
              ),
            )
          : _videos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        color: NGColors.textMuted,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.tag != null
                            ? 'No videos with #${widget.tag}'
                            : 'No videos found',
                        style: TextStyle(
                          color: NGColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final v = _videos[index];
                    return ListTile(
                      leading: v.profileImageUrl != null && v.profileImageUrl!.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(v.profileImageUrl!),
                            )
                          : const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                      title: Text(
                        v.username,
                        style: TextStyle(
                          color: NGColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        v.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NGColors.textSecondary,
                        ),
                      ),
                      trailing: Text(
                        '❤️ ${v.likeCount}',
                        style: TextStyle(
                          color: NGColors.textMuted,
                        ),
                      ),
                      onTap: () {
                        // Navigate to video detail
                      },
                    );
                  },
                ),
    );
  }
}
