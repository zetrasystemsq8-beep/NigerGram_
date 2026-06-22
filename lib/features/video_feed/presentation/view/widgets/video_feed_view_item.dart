// lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart
import 'package:flutter/material.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';
import 'video_feed_view_optimized_video_player.dart';
import 'video_feed_view_interaction_buttons.dart';

class VideoFeedViewItem extends StatelessWidget {
  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  const VideoFeedViewItem({
    super.key,
    required this.videoItem,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Restructured to prevent gesture conflicts
    // Video player + center tap zone (for play/pause)
    return Stack(
      children: [
        // LAYER 1: Video Player (with GestureDetector for tap-to-play/pause)
        Positioned.fill(
          child: VideoFeedViewOptimizedVideoPlayer(
            controller: controller,
            videoId: videoItem.id,
          ),
        ),

        // LAYER 2: Dark gradient overlay (non-interactive, IgnorePointer)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black45,
                    Colors.black87,
                  ],
                  stops: [0.6, 0.85, 1.0],
                ),
              ),
            ),
          ),
        ),

        // LAYER 3: Top-left user info (non-blocking)
        Positioned(
          bottom: 32,
          left: 16,
          right: 88,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${videoItem.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  videoItem.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),

        // LAYER 4: Right-side interaction buttons (interactive, allows taps to pass through center)
        Positioned(
          bottom: 100,
          right: 12,
          child: VideoFeedViewInteractionButtons(
            videoId: videoItem.id,
            isLiked: videoItem.isLiked ?? false,
            likeCount: videoItem.likeCount,
            commentCount: videoItem.commentCount,
            shareCount: videoItem.shareCount,
            isBookmarked: videoItem.isBookmarked ?? false,
            creatorId: videoItem.creatorId,
            creatorUsername: videoItem.username,
            onShareTapped: () {
              // Native share implementation will be added
            },
            onBookmarkTapped: () {
              // Bookmark logic
            },
          ),
        ),
      ],
    );
  }
}
