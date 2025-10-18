import 'package:flutter/material.dart';
import 'package:flutter_video_feed/core/config/localization/app_localizations.dart';
import 'package:flutter_video_feed/core/design_system/colors.dart';
import 'package:flutter_video_feed/core/utils/extensions/context_size_extensions.dart';

class VideoFeedViewFollowButton extends StatelessWidget {
  const VideoFeedViewFollowButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: context.paddingHorizontal(8),
      margin: context.paddingLeft(12),
      decoration: BoxDecoration(
        border: Border.all(color: white),
        borderRadius: context.radiusAll(8),
      ),
      child: Text(
        AppLocalizations.of(context)!.follow,
        style: TextStyle(color: white, fontSize: context.fontSize(16)),
      ),
    );
  }
}
