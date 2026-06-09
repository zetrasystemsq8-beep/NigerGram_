import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class VideoFeedViewInteractionButton extends StatefulWidget {
  const VideoFeedViewInteractionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.iconColor = white,
    super.key,
  });

  final IconData icon;
  final int count;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<VideoFeedViewInteractionButton> createState() =>
      _VideoFeedViewInteractionButtonState();
}

class _VideoFeedViewInteractionButtonState
    extends State<VideoFeedViewInteractionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleAnimationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.3)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.3, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticIn)),
          weight: 50),
    ]).animate(_scaleAnimationController);
  }

  @override
  void dispose() {
    _scaleAnimationController.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _scaleAnimationController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              widget.icon,
              color: widget.iconColor,
              size: context.sq(38),
              shadows: const [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          SizedBox(height: context.h(3)),
          Text(
            _formatCount(widget.count),
            style: TextStyle(
              color: white,
              fontSize: context.fontSize(12.5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
