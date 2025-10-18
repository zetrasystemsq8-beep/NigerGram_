import 'package:flutter/material.dart';
import 'package:flutter_video_feed/core/design_system/colors.dart';

class VideoFeedViewDescriptionText extends StatelessWidget {
  const VideoFeedViewDescriptionText({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.length > 30 ? '${text.substring(0, 30)}...' : text,
      style: const TextStyle(color: white, fontSize: 18),
    );
  }
}
