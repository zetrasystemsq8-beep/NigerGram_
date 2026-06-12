import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Institutional-Grade Interaction Stack for NigerGram
/// Orchestrates Like, Comment, Share, and Bookmark actions with spring physics.
class VideoFeedViewInteractionButtons extends StatelessWidget {
  const VideoFeedViewInteractionButtons({
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.onLikeTapped,
    this.isBookmarked = false,
    this.onCommentTapped,
    this.onShareTapped,
    this.onBookmarkTapped,
    super.key,
  });

  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isBookmarked;
  final VoidCallback onLikeTapped;
  final VoidCallback? onCommentTapped;
  final VoidCallback? onShareTapped;
  final VoidCallback? onBookmarkTapped;

  @override
  Widget build(BuildContext context) {
    // Standard native sizing framework to avoid external dependency breaks
    final double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like Button
        VideoFeedViewInteractionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(likeCount),
          iconColor: isLiked ? const Color(0xFFFE2C55) : Colors.white,
          onTap: onLikeTapped,
        ),
        SizedBox(height: screenHeight * 0.02),

        // Comment Button
        VideoFeedViewInteractionButton(
          icon: Icons.chat_bubble_rounded,
          label: _formatCount(commentCount),
          onTap: () {
            if (onCommentTapped != null) {
              onCommentTapped!();
            }
          },
        ),
        SizedBox(height: screenHeight * 0.02),

        // Share Button
        VideoFeedViewInteractionButton(
          icon: Icons.reply_rounded,
          label: _formatCount(shareCount),
          onTap: () {
            HapticFeedback.mediumImpact();
            if (onShareTapped != null) {
              onShareTapped!();
            }
          },
        ),
        SizedBox(height: screenHeight * 0.02),

        // Bookmark Button
        VideoFeedViewInteractionButton(
          icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          label: "Save",
          iconColor: isBookmarked ? Colors.amber : Colors.white,
          onTap: () {
            if (onBookmarkTapped != null) {
              onBookmarkTapped!();
            }
          },
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class VideoFeedViewInteractionButton extends StatefulWidget {
  const VideoFeedViewInteractionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<VideoFeedViewInteractionButton> createState() => _VideoFeedViewInteractionButtonState();
}

class _VideoFeedViewInteractionButtonState extends State<VideoFeedViewInteractionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            Icon(
              widget.icon,
              color: widget.iconColor,
              size: 38,
              shadows: const [
                Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
