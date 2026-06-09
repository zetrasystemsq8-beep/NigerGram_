import 'package:flutter/material.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_description_text.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_user_header.dart';

class VideoFeedViewUserInfoSection extends StatelessWidget {
  const VideoFeedViewUserInfoSection({
    required this.profileImageUrl,
    required this.username,
    required this.description,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final String description;

  @override
  Widget build(BuildContext context) {
    // Removed the redundant internal padding wrapper to prevent double-padding displacement,
    // ensuring the text elements line up flawlessly with the primary overlay layout grid.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: context.h(8),
      children: [
        VideoFeedViewUserHeader(
          profileImageUrl: profileImageUrl,
          username: username,
        ),
        VideoFeedViewDescriptionText(text: description),
      ],
    );
  }
}
