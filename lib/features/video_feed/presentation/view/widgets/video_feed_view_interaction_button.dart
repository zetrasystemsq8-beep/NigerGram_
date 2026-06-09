import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class VideoFeedViewInteractionButton extends StatelessWidget {
  const VideoFeedViewInteractionButton({
    required this.icon,
    required this.count,
    super.key,
    this.color = white,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: context.h(4),
      children: [
        Icon(
          icon, 
          color: color, 
          size: context.sq(36),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            color: white,
            fontSize: context.fontSize(14),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
