import 'package:flutter/material.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_interaction_buttons.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_user_info_section.dart';

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
    required this.onLikeTapped,
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
  final VoidCallback onLikeTapped;

  @override
  Widget build(BuildContext context) {
    // Force alignment constraints directly within the Stack container space
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false, // Allow layout to bypass upper notch boundaries
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 12.0, bottom: 16.0),
          child: RepaintBoundary(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Wrap in Expanded to guarantee long descriptions truncate or wrap cleanly 
                // without displacing right-side button layouts
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24.0),
                    child: VideoFeedViewUserInfoSection(
                      profileImageUrl: profileImageUrl,
                      username: username,
                      description: description,
                    ),
                  ),
                ),
                
                // Static column layout holding your interaction buttons
                VideoFeedViewInteractionButtons(
                  isLiked: isLiked,
                  isBookmarked: isBookmarked,
                  likeCount: likeCount,
                  commentCount: commentCount,
                  shareCount: shareCount,
                  onLikeTapped: onLikeTapped,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
