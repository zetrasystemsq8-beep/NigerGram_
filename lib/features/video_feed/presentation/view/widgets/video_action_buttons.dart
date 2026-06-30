// lib/features/video_feed/presentation/view/widgets/video_action_buttons.dart

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nigergram/core/design_system/colors.dart';

class VideoActionButtons extends StatelessWidget {
  final String videoUrl;
  final String videoId;
  final String username;
  final int likeCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const VideoActionButtons({
    super.key,
    required this.videoUrl,
    required this.videoId,
    required this.username,
    required this.likeCount,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  void _downloadVideo() {
    Share.share(
      videoUrl,
      subject: 'Save this video from NigerGram',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 120,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like Button
          _ActionButton(
            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: likeCount > 0 ? '${likeCount}' : 'Like',
            color: isLiked ? Colors.red : null,
            onTap: onLike,
          ),
          const SizedBox(height: 16),

          // Comment Button
          _ActionButton(
            icon: Icons.comment_rounded,
            label: 'Comment',
            onTap: onComment,
          ),
          const SizedBox(height: 16),

          // Share Button
          _ActionButton(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: onShare,
          ),
          const SizedBox(height: 16),

          // Download/Save Button
          _ActionButton(
            icon: Icons.download_rounded,
            label: 'Save',
            onTap: _downloadVideo,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color ?? Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
