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
  
  // Optional callbacks prevent compilation failures while keeping components non-MVP
  final VoidCallback? onCommentTapped;
  final VoidCallback? onShareTapped;
  final VoidCallback? onBookmarkTapped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Cleared duplicate horizontal margins to let the parent overlay constraints manage placement
      padding: EdgeInsets.only(
        bottom: context.h(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: context.h(20),
        children: [
          // Like Interactive Node
          GestureDetector(
            onTap: onLikeTapped,
            behavior: HitTestBehavior.opaque, // Expands hit response to encompass whitespace gaps
            child: VideoFeedViewInteractionButton(
              icon: isLiked ? Icons.favorite : Icons.favorite_border,
              count: likeCount,
              color: isLiked ? red : white,
          	),
          ),
          
          // Comment Interactive Node
          GestureDetector(
            onTap: onCommentTapped,
            behavior: HitTestBehavior.opaque,
            child: VideoFeedViewInteractionButton(
              icon: LucideIcons.messageCircle,
              count: commentCount,
            ),
          ),
          
          // Share Interactive Node
          GestureDetector(
            onTap: onShareTapped,
            behavior: HitTestBehavior.opaque,
            child: VideoFeedViewInteractionButton(
              icon: LucideIcons.send,
              count: shareCount,
            ),
          ),
          
          // Bookmark Interactive Node 
          // Wrapped cleanly inside an opaque responder to keep hit areas matching the buttons above
          GestureDetector(
            onTap: onBookmarkTapped,
            behavior: HitTestBehavior.opaque,
            child: Column(
              spacing: context.h(4),
              children: [
                Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: white,
                  size: context.sq(36),
                ),
                // Maintains vertical layout symmetry matching the spacing of the counters above
                SizedBox(height: context.fontSize(16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
