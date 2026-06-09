import 'package:flutter/material.dart';
import 'package:nigergram/core/config/localization/app_localizations.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class VideoFeedViewFollowButton extends StatefulWidget {
  const VideoFeedViewFollowButton({this.onFollowChanged, super.key});

  /// Optional execution callback to notify parent controllers or state machines
  final ValueChanged<bool>? onFollowChanged;

  @override
  State<VideoFeedViewFollowButton> createState() => _VideoFeedViewFollowButtonState();
}

class _VideoFeedViewFollowButtonState extends State<VideoFeedViewFollowButton> {
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final String followLabel = localizations?.follow ?? 'Follow';
    
    // Non-MVP feature enhancement: Handle localized following state labels
    final String followingLabel = localizations?.following ?? 'Following';

    return GestureDetector(
      onTap: () {
        setState(() {
          _isFollowing = !_isFollowing;
        });
        if (widget.onFollowChanged != null) {
          widget.onFollowChanged!(_isFollowing);
        }
      },
      behavior: HitTestBehavior.opaque, // Ensures the entire bounding geometry registers fast taps
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: context.paddingHorizontal(10),
        margin: context.paddingLeft(12),
        height: context.h(28), // Enforces a solid, standardized visual profile inside the user header row
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isFollowing ? white.withAlpha(30) : Colors.transparent,
          border: Border.all(
            color: _isFollowing ? white.withAlpha(120) : white,
            width: 1.5,
          ),
          borderRadius: context.radiusAll(6),
        ),
        child: Text(
          _isFollowing ? followingLabel : followLabel,
          style: TextStyle(
            color: _isFollowing ? white.withAlpha(180) : white,
            fontSize: context.fontSize(13),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
