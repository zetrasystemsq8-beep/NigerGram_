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
    this.onCommentTapped,
    this.onShareTapped,
    this.onBookmarkTapped,
    super.key,
  });

  final bool isLiked;
  final bool isBookmarked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final VoidCallback onLikeTapped;
  final VoidCallback? onCommentTapped;
  final VoidCallback? onShareTapped;
  final VoidCallback? onBookmarkTapped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.h(4)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: context.h(20),
        children: [
          VideoFeedViewInteractionButton(
            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_rounded,
            count: likeCount,
            iconColor: isLiked ? const Color(0xFFFE2C55) : white,
            onTap: onLikeTapped,
          ),
          VideoFeedViewInteractionButton(
            icon: LucideIcons.messageCircle,
            count: commentCount,
            onTap: onCommentTapped ?? () {},
          ),
          VideoFeedViewInteractionButton(
            icon: LucideIcons.send,
            count: shareCount,
            onTap: onShareTapped ?? () {},
          ),
          GestureDetector(
            onTap: onBookmarkTapped,
            child: Column(
              children: [
                Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: white,
                  size: context.sq(36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
