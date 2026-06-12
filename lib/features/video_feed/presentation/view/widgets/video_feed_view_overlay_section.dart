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
              GestureDetector(
                onTap: () {},
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: context.sq(18),
                      backgroundImage: profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                      backgroundColor: Colors.white12,
                      child: profileImageUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white54)
                          : null,
                    ),
                    SizedBox(width: context.w(10)),
                    Text(
                      username,
                      style: TextStyle(
                        color: white,
                        fontSize: context.fontSize(15),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(8)),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: white,
                  fontSize: context.fontSize(14),
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
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_outline,
                        color: isLiked ? const Color(0xFFFF0050) : white,
                        size: context.sq(28),
                      ),
                    ),
                    SizedBox(height: context.h(4)),
                    Text(
                      likeCount > 999
                          ? '${(likeCount / 1000).toStringAsFixed(1)}k'
                          : '$likeCount',
                      style: TextStyle(
                        color: white,
                        fontSize: context.fontSize(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(16)),

              // ✅ FIXED: Comments button with count badge
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
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.message_outlined,
                            color: white,
                            size: context.sq(28),
                          ),
                        ),
                        // ✅ NEW: Red badge with comment count
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
                                color: Color(0xFFFF0050),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                commentCount > 99
                                    ? '99+'
                                    : '$commentCount',
                                style: TextStyle(
                                  color: white,
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
                      commentCount > 999
                          ? '${(commentCount / 1000).toStringAsFixed(1)}k'
                          : '$commentCount',
                      style: TextStyle(
                        color: white,
                        fontSize: context.fontSize(12),
                        fontWeight: FontWeight.w600,
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
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: white,
                        size: context.sq(28),
                      ),
                    ),
                    SizedBox(height: context.h(4)),
                    Text(
                      shareCount > 999
                          ? '${(shareCount / 1000).toStringAsFixed(1)}k'
                          : '$shareCount',
                      style: TextStyle(
                        color: white,
                        fontSize: context.fontSize(12),
                        fontWeight: FontWeight.w600,
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
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pause_rounded,
                    color: white.withOpacity(0.6),
                    size: context.sq(28),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
