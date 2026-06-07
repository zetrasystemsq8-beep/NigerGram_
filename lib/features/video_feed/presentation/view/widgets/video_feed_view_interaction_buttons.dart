import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_interaction_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoFeedViewInteractionButtons extends StatelessWidget {
  const VideoFeedViewInteractionButtons({
    required this.isLiked,
    required this.isBookmarked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.onLikeTapped,
    super.key,
  });

  final bool isLiked;
  final bool isBookmarked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final VoidCallback onLikeTapped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: context.h(16),
        right: context.w(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: context.h(20),
        children: [
          GestureDetector(
            onTap: onLikeTapped,
            child: VideoFeedViewInteractionButton(
              icon: isLiked ? Icons.favorite : Icons.favorite_border,
              count: likeCount,
              color: isLiked ? red : white,
            ),
          ),
          VideoFeedViewInteractionButton(
            icon: LucideIcons.messageCircle,
            count: commentCount,
          ),
          VideoFeedViewInteractionButton(
            icon: LucideIcons.send,
            count: shareCount,
          ),
          Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: white,
            size: context.sq(36),
          ),
        ],
      ),
    );
  }
}
