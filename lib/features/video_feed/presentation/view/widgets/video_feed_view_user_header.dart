// lib/features/video_feed/presentation/widgets/video_feed_view_user_header.dart
import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_follow_button.dart';

class VideoFeedViewUserHeader extends StatelessWidget {
  const VideoFeedViewUserHeader({
    required this.profileImageUrl,
    required this.username,
    required this.isFollowing,
    required this.isOwnVideo,
    required this.onFollowTap,
    this.onProfileTap,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final bool isFollowing;
  final bool isOwnVideo;
  final VoidCallback onFollowTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      // `Row` does not support a `spacing` named parameter. Use an explicit
      // SizedBox between children for consistent spacing.
      children: [
        // Profile Avatar with NGColors
        GestureDetector(
          onTap: onProfileTap,
          child: CircleAvatar(
            radius: context.sq(20),
            backgroundColor: NGColors.surface, // ✅ Not hardcoded
            foregroundImage: profileImageUrl.isNotEmpty
                ? NetworkImage(profileImageUrl)
                : null,
            onForegroundImageError: (exception, stackTrace) {
              debugPrint('NigerGram Log: Profile Image failed - $exception');
            },
            child: Icon(
              Icons.person_rounded,
              color: NGColors.textMuted, // ✅ Not hardcoded
              size: context.sq(20),
            ),
          ),
        ),

        // Explicit spacing replacing the unsupported `spacing:` parameter
        SizedBox(width: context.w(8)),

        // Username
        Flexible(
          child: GestureDetector(
            onTap: onProfileTap,
            child: Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: NGColors.textPrimary, // ✅ Not hardcoded
                fontWeight: FontWeight.bold,
                fontSize: context.fontSize(18),
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Follow Button (only if not own video)
        if (!isOwnVideo)
          VideoFeedViewFollowButton(
            isFollowing: isFollowing,
            onTap: onFollowTap,
          ),
      ],
    );
  }
}
