import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';

class VideoFeedViewInteractionButtons extends StatelessWidget {
  const VideoFeedViewInteractionButtons({
    required this.isLiked,
    required this.isBookmarked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.onLikeTapped,
    super.key,
  });

  final bool isLiked;
  final bool isBookmarked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final VoidCallback onLikeTapped;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _AnimatedProfileAvatarNode(
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
        ),
        SizedBox(height: context.h(20)),
        VideoFeedViewInteractionButton(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_rounded,
          count: likeCount,
          iconColor: isLiked ? const Color(0xFFFE2C55) : white,
          onTap: onLikeTapped,
        ),
        SizedBox(height: context.h(16)),
        VideoFeedViewInteractionButton(
          icon: Icons.chat_bubble_rounded,
          count: commentCount,
          onTap: () {},
        ),
        SizedBox(height: context.h(16)),
        _StatefulBookmarkButton(
          isBookmarked: isBookmarked,
          count: 0,
        ),
        SizedBox(height: context.h(16)),
        VideoFeedViewInteractionButton(
          icon: Icons.reply_rounded,
          count: 0,
          onTap: () {},
        ),
      ],
    );
  }
}

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

  String _formatMetricCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _executeInteractionSequence() {
    HapticFeedback.lightImpact();
    _scaleAnimationController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _executeInteractionSequence,
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
            _formatMetricCount(widget.count),
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

class _StatefulBookmarkButton extends StatefulWidget {
  const _StatefulBookmarkButton(
      {required this.isBookmarked, required this.count});
  final bool isBookmarked;
  final int count;

  @override
  State<_StatefulBookmarkButton> createState() =>
      _StatefulBookmarkButtonState();
}

class _StatefulBookmarkButtonState extends State<_StatefulBookmarkButton> {
  late bool _innerBookmarkState;
  late int _innerCount;

  @override
  void initState() {
    super.initState();
    _innerBookmarkState = widget.isBookmarked;
    _innerCount = widget.count;
  }

  @override
  Widget build(BuildContext context) {
    return VideoFeedViewInteractionButton(
      icon: Icons.bookmark_rounded,
      count: _innerCount,
      iconColor: _innerBookmarkState ? const Color(0xFFFACE15) : white,
      onTap: () {
        setState(() {
          _innerBookmarkState = !_innerBookmarkState;
          _innerCount =
              _innerBookmarkState ? _innerCount + 1 : _innerCount - 1;
        });
      },
    );
  }
}

class _AnimatedProfileAvatarNode extends StatefulWidget {
  const _AnimatedProfileAvatarNode({required this.avatarUrl});
  final String avatarUrl;

  @override
  State<_AnimatedProfileAvatarNode> createState() =>
      _AnimatedProfileAvatarNodeState();
}

class _AnimatedProfileAvatarNodeState extends State<_AnimatedProfileAvatarNode>
    with SingleTickerProviderStateMixin {
  bool _isFollowing = false;
  late final AnimationController _badgeHideController;
  late final Animation<double> _badgeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _badgeHideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _badgeScaleAnimation =
        CurveTween(curve: Curves.easeIn).animate(_badgeHideController);
  }

  @override
  void dispose() {
    _badgeHideController.dispose();
    super.dispose();
  }

  void _triggerFollowAction() {
    HapticFeedback.mediumImpact();
    _badgeHideController.forward().then((_) {
      setState(() => _isFollowing = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.w(52),
      height: context.h(58),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: context.sq(48),
            height: context.sq(48),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                widget.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) =>
                    const Icon(Icons.person, color: white),
              ),
            ),
          ),
          if (!_isFollowing)
            Positioned(
              bottom: 0,
              child: ScaleTransition(
                scale: _badgeScaleAnimation,
                child: GestureDetector(
                  onTap: _triggerFollowAction,
                  child: Container(
                    width: context.sq(22),
                    height: context.sq(22),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFE2C55),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: white,
                      size: context.sq(16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
