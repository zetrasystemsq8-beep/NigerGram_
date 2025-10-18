import 'package:flutter/material.dart';
import 'package:flutter_video_feed/features/video_feed/presentation/view/widgets/video_feed_view_interaction_buttons.dart';
import 'package:flutter_video_feed/features/video_feed/presentation/view/widgets/video_feed_view_user_info_section.dart';

class VideoFeedViewOverlaySection extends StatelessWidget {
  const VideoFeedViewOverlaySection({
    required this.profileImageUrl,
    required this.username,
    required this.description,
    required this.isBookmarked,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final String description;
  final bool isBookmarked;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          VideoFeedViewUserInfoSection(profileImageUrl: profileImageUrl, username: username, description: description),
          VideoFeedViewInteractionButtons(
            isLiked: isLiked,
            isBookmarked: isBookmarked,
            likeCount: likeCount,
            commentCount: commentCount,
            shareCount: shareCount,
          ),
        ],
      ),
    );
  }
}
