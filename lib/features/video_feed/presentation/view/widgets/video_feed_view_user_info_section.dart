import 'package:flutter/material.dart';
import 'package:flutter_video_feed/features/video_feed/presentation/view/widgets/video_feed_view_description_text.dart';
import 'package:flutter_video_feed/features/video_feed/presentation/view/widgets/video_feed_view_user_header.dart';

class VideoFeedViewUserInfoSection extends StatelessWidget {
  const VideoFeedViewUserInfoSection({required this.profileImageUrl, required this.username, required this.description, super.key});

  final String profileImageUrl;
  final String username;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 8,
        children: [
          VideoFeedViewUserHeader(profileImageUrl: profileImageUrl, username: username),
          VideoFeedViewDescriptionText(text: description),
        ],
      ),
    );
  }
}
