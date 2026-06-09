import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_follow_button.dart';

class VideoFeedViewUserHeader extends StatelessWidget {
  const VideoFeedViewUserHeader({
    required this.profileImageUrl,
    required this.username,
    super.key,
  });

  final String profileImageUrl;
  final String username;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: context.w(8),
      children: [
        // Optimized Profile Avatar with structured image streaming safety checks
        CircleAvatar(
          radius: context.sq(20),
          backgroundColor: Colors.grey[900], 
          foregroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
          onForegroundImageError: (exception, stackTrace) {
            debugPrint('NigerGram Log: Profile Image streaming timed out or failed - $exception');
          },
          child: Icon(
            Icons.person,
            color: white.withAlpha(128),
            size: context.sq(20),
          ),
        ),
        
        // Flexible bounds container prevents long creator handles from creating row layout crashes
        Flexible(
          child: Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: white,
              fontWeight: FontWeight.bold,
              fontSize: context.fontSize(18),
            ),
          ),
        ),
        
        // Immersive Action Element
        const VideoFeedViewFollowButton(),
      ],
    );
  }
}
