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
    // Use the optimized player widget which contains the GestureDetector and overlay
    return Stack(
      children: [
        Positioned.fill(
          child: VideoFeedViewOptimizedVideoPlayer(
            controller: controller,
            videoId: videoItem.id,
          ),
        ),
        Positioned.fill(child: _DecorateBackgroundGradient()),

        // Right-side interaction column replaced with live interaction widget
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
              // Optionally implement platform share logic here
            },
            onBookmarkTapped: () {
              // Optionally implement bookmark logic
            },
          ),
        ),

        Positioned(
          bottom: 32,
          left: 16,
          right: 88,
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
      ],
    );
  }

  Widget _buildProfileIcon(String url) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[900],
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: url.isEmpty ? const Icon(Icons.person_rounded, color: Colors.white54) : null,
          ),
        ),
        Positioned(
          bottom: -6,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFF0050),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionButton(
    IconData icon,
    String countingLabel, {
    Color color = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 4),
        Text(
          countingLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
