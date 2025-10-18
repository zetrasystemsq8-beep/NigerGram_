import 'package:flutter/material.dart';
import 'package:flutter_video_feed/core/design_system/colors.dart';
import 'package:flutter_video_feed/core/utils/extensions/context_size_extensions.dart';
import 'package:flutter_video_feed/features/video_feed/presentation/view/widgets/video_feed_view_follow_button.dart';

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
        CircleAvatar(
          radius: context.sq(20),
          backgroundImage: NetworkImage(profileImageUrl),
        ),
        Text(
          username,
          style: TextStyle(
            color: white,
            fontWeight: FontWeight.bold,
            fontSize: context.fontSize(18),
          ),
        ),
        const VideoFeedViewFollowButton(),
      ],
    );
  }
}
