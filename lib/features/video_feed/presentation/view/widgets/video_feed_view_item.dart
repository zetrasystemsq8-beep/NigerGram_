import 'package:flutter/material.dart';
import 'package:flutter_video_feed/features/video_feed/domain/entities/video_entity.dart';
import 'package:flutter_video_feed/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart';
import 'package:flutter_video_feed/features/video_feed/presentation/view/widgets/video_feed_view_overlay_section.dart';
import 'package:video_player/video_player.dart';

class VideoFeedViewItem extends StatelessWidget {
  const VideoFeedViewItem({required this.videoItem, required this.controller, super.key});

  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VideoFeedViewOptimizedVideoPlayer(controller: controller, videoId: videoItem.id),
        VideoFeedViewOverlaySection(
          profileImageUrl: videoItem.profileImageUrl,
          username: videoItem.username,
          description: videoItem.description,
          isBookmarked: false,
          isLiked: false,
          likeCount: videoItem.likeCount,
          commentCount: videoItem.commentCount,
          shareCount: videoItem.shareCount,
        ),
      ],
    );
  }
}
