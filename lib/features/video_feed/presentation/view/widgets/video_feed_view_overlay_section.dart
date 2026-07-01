// lib/features/video_feed/presentation/widgets/video_feed_view_overlay_section.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

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
    required this.onPlayPauseTapped,
    required this.onCommentTapped,
    required this.onShareTapped,
    required this.isPaused,
    this.isVerified = false,
    this.isFollowing = false,
    this.isOwnVideo = false,
    this.onFollowTap,
    this.onProfileTap,
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
  final VoidCallback onPlayPauseTapped;
  final VoidCallback onCommentTapped;
  final VoidCallback onShareTapped;
  final bool isPaused;
  final bool isVerified;
  final bool isFollowing;
  final bool isOwnVideo;
  final VoidCallback? onFollowTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // User info at bottom-left
        Positioned(
          bottom: context.h(80),
          left: context.w(12),
          right: context.w(70),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User row: Avatar + Username + Follow
              Row(
                children: [
                  GestureDetector(
                    onTap: onProfileTap,
                    child: CircleAvatar(
                      radius: context.sq(18),
                      backgroundImage: profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                      backgroundColor: NGColors.surfaceLight,
                      child: profileImageUrl.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              color: NGColors.textMuted,
                              size: context.sq(18),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(width: context.w(10)),
                  Expanded(
                    child: GestureDetector(
                      onTap: onProfileTap,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@$username',
                              style: TextStyle(
                                color: NGColors.textPrimary,
                                fontSize: context.fontSize(15),
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              color: NGColors.verified,
                              size: context.sq(14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Follow button (if not own video)
                  if (!isOwnVideo && onFollowTap != null)
                    GestureDetector(
                      onTap: onFollowTap,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.w(10),
                          vertical: context.h(4),
                        ),
                        decoration: BoxDecoration(
                          color: isFollowing
                              ? NGColors.surfaceLight
                              : NGColors.accent,
                          borderRadius: BorderRadius.circular(16),
                          border: isFollowing
                              ? Border.all(
                                  color: NGColors.divider,
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: isFollowing
                                ? NGColors.textSecondary
                                : NGColors.textPrimary,
                            fontSize: context.fontSize(11),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: context.h(8)),
              // Description
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: NGColors.textSecondary,
                  fontSize: context.fontSize(14),
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Right-side action buttons
        Positioned(
          bottom: context.h(80),
          right: context.w(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Like button
              GestureDetector(
                onTap: onLikeTapped,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.sq(8)),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        color: isLiked ? NGColors.like : NGColors.textPrimary,
                        size: context.sq(28),
                      ),
                    ),
                    SizedBox(height: context.h(4)),
                    Text(
                      _formatCount(likeCount),
                      style: TextStyle(
                        color: NGColors.textPrimary,
                        fontSize: context.fontSize(12),
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(16)),

              // Comment button with badge
              GestureDetector(
                onTap: onCommentTapped,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.sq(8)),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: NGColors.textPrimary,
                            size: context.sq(28),
                          ),
                        ),
                        if (commentCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.w(4),
                                vertical: context.h(2),
                              ),
                              decoration: const BoxDecoration(
                                color: NGColors.like,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                commentCount > 99 ? '99+' : '$commentCount',
                                style: TextStyle(
                                  color: NGColors.textPrimary,
                                  fontSize: context.fontSize(10),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: context.h(4)),
                    Text(
                      _formatCount(commentCount),
                      style: TextStyle(
                        color: NGColors.textPrimary,
                        fontSize: context.fontSize(12),
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(16)),

              // Share button
              GestureDetector(
                onTap: onShareTapped,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.sq(8)),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: NGColors.textPrimary,
                        size: context.sq(28),
                      ),
                    ),
                    SizedBox(height: context.h(4)),
                    Text(
                      _formatCount(shareCount),
                      style: TextStyle(
                        color: NGColors.textPrimary,
                        fontSize: context.fontSize(12),
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(16)),

              // Play/Pause indicator (optional)
              if (isPaused)
                Container(
                  padding: EdgeInsets.all(context.sq(8)),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.pause_rounded,
                    color: NGColors.textPrimary.withOpacity(0.6),
                    size: context.sq(28),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
