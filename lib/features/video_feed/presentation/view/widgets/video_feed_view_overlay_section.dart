import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_interaction_buttons.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_user_info_section.dart';

class VideoFeedViewOverlaySection extends StatefulWidget {
  const VideoFeedViewOverlaySection({
    required this.profileImageUrl,
    required this.username,
    required this.description,
    required this.isBookmarked,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.onLikeTapped,
    super.key,
  });

  final String profileImageUrl;
  final String username;
  final String description;
  final bool isBookmarked;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final VoidCallback onLikeTapped;

  @override
  State<VideoFeedViewOverlaySection> createState() => _VideoFeedViewOverlaySectionState();
}

class _VideoFeedViewOverlaySectionState extends State<VideoFeedViewOverlaySection> with SingleTickerProviderStateMixin {
  late final AnimationController _vinylRotationController;

  @override
  void initState() {
    super.initState();
    // Continuous, uninterrupted linear execution loop for the audio disc spinning frame
    _vinylRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _vinylRotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Anti-Washout Linear Gradient Vignette Mask
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: context.h(220),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withAlpha(40),
                  Colors.black.withAlpha(120),
                  Colors.black.withAlpha(200), // Solid contrast anchor at screen baseline
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // 2. Interactive Controls Grid Layout
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: context.w(14),
                    right: context.w(10),
                    bottom: context.h(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // User Info & Caption Block (Auto-wrapping execution bounds)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: context.w(16)),
                          child: VideoFeedViewUserInfoSection(
                            profileImageUrl: widget.profileImageUrl,
                            username: widget.username,
                            description: widget.description,
                          ),
                        ),
                      ),

                      // Interaction Control Tower Column
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoFeedViewInteractionButtons(
                            isLiked: widget.isLiked,
                            isBookmarked: widget.isBookmarked,
                            likeCount: widget.likeCount,
                            commentCount: widget.commentCount,
                            shareCount: widget.shareCount,
                            onLikeTapped: widget.onLikeTapped,
                          ),
                          SizedBox(height: context.h(12)),
                          
                          // High-Fidelity 360° Rotating Album Vinyl Disk Node
                          RotationTransition(
                            turns: _vinylRotationController,
                            child: Container(
                              width: context.sq(38),
                              height: context.sq(38),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0xFF2C2C2C),
                                    Color(0xFF111111),
                                    Color(0xFF050505),
                                  ],
                                  stops: [0.0, 0.7, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(7.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1F1F1F),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    widget.profileImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, _, __) => const Icon(
                                      Icons.music_note_rounded,
                                      color: white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 3. Ultra-Thin Premium Progress Scrub Timeline Bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.w(4)),
                  child: Container(
                    height: 2.0, // Sleek, non-obtrusive, clean hairline timeline
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: white.withAlpha(40),
                      borderRadius: BorderRadius.circular(1),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.35, // Mock baseline tracker status percentage
                      child: Container(
                        height: 2.0,
                        decoration: BoxDecoration(
                          color: white.withAlpha(220),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
