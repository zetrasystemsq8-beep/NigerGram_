// lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';
import 'video_feed_view_optimized_video_player.dart';
import 'video_feed_view_interaction_buttons.dart';
import 'comments_viewer_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';

class VideoFeedViewItem extends StatelessWidget {
  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  const VideoFeedViewItem({
    super.key,
    required this.videoItem,
    required this.controller,
  });

  /// 📥 THE REAL-TIME NIGERGRAM COMMENT ENGINE MODAL
  void _openCommentsModalSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return CommentsViewerBottomSheet(videoId: videoItem.id);
      },
    );
  }

  /// 🔗 Use native share sheet via share_plus
  Future<void> _executePlatformShareAction(BuildContext context) async {
    HapticFeedback.lightImpact();

    final String? videoId = videoItem.id;
    final String? creator = videoItem.username;
    final String videoUrl = (videoId != null && videoId.isNotEmpty)
        ? 'https://nigergram.app/video/$videoId'
        : '';

    final bool hasUrl = videoUrl.isNotEmpty;
    final String subject = (creator != null && creator.isNotEmpty) ? '@$creator on NigerGram' : 'NigerGram';
    final String content = hasUrl
        ? 'Watch this on NigerGram: $videoUrl'
        : 'Check out this video on NigerGram!';

    try {
      await Share.share(content, subject: subject);
    } catch (error) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Could not share the video. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // LAYER 1: Hardware Video Player Component Texture
        Positioned.fill(
          child: VideoFeedViewOptimizedVideoPlayer(
            controller: controller,
            videoId: videoItem.id,
            creatorUsername: videoItem.username,
          ),
        ),

        // LAYER 2: Non-interactive Vignette Shader Gradient
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black45,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.2, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),

        // LAYER 3: Interactive Left-Side Metadata Panel
        Positioned(
          bottom: 16,
          left: 16,
          right: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/profile/${videoItem.creatorId}');
                },
                child: Text(
                  '@${videoItem.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                videoItem.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE4E6EB),
                  fontSize: 14,
                  height: 1.3,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                ),
              ),
            ],
          ),
        ),

        // LAYER 4: Right-Side Floating Actions Dock Interceptor
        Positioned(
          bottom: 40,
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
            onCommentTapped: () => _openCommentsModalSheet(context),
            onShareTapped: () => _executePlatformShareAction(context),
            onBookmarkTapped: () {
              HapticFeedback.selectionClick();
            },
          ),
        ),
      ],
    );
  }
}
