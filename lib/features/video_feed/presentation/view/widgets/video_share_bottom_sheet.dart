// lib/features/video_feed/presentation/view/widgets/video_share_bottom_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/design_system/colors.dart';

class VideoShareBottomSheet extends StatelessWidget {
  final String videoId;
  final String username;
  final String description;

  const VideoShareBottomSheet({
    super.key,
    required this.videoId,
    required this.username,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final deepLink = 'nigergram://video/$videoId';
    final message = '🎬 Check out @$username on NigerGram: $description\n$deepLink';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: NGColors.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NGColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Share Video',
                  style: TextStyle(
                    color: NGColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Share this video with your community',
                  style: TextStyle(
                    color: NGColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                // Share options grid
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.1,
                  children: [
                    _ShareOption(
                      icon: Icons.send,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () {
                        Navigator.pop(context);
                        // WhatsApp share
                      },
                    ),
                    _ShareOption(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Twitter',
                      color: const Color(0xFF1DA1F2),
                      onTap: () {
                        Navigator.pop(context);
                        // Twitter share
                      },
                    ),
                    _ShareOption(
                      icon: Icons.copy,
                      label: 'Copy Link',
                      color: NGColors.accent,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: deepLink));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Link copied to clipboard'),
                            backgroundColor: NGColors.accent,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    _ShareOption(
                      icon: Icons.more_horiz_rounded,
                      label: 'More',
                      color: NGColors.textMuted,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: NGColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
