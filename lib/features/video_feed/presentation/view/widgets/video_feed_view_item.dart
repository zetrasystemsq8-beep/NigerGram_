// lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart
import 'package:flutter/material.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';
import 'video_feed_view_optimized_video_player.dart';
import 'video_feed_view_interaction_buttons.dart';

class VideoFeedViewItem extends StatelessWidget {
  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  const VideoFeedViewItem({
    super.key,
    required this.videoItem,
    required this.controller,
  });

  /// 📥 THE TIKTOK-STYLE COMMENT SHEET SYSTEM
  /// In an interview: Explain that we use a Modal Bottom Sheet with an explicit
  /// [isScrollControlled: true] parameter so it can dynamically cover 65% of the 
  /// screen without pushing the underlying video view off the navigation stack.
  void _openCommentsModalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, // Allows custom rounded corner clipping
      barrierColor: Colors.black.withOpacity(0.5), // Elegant dim overlay
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65, // Opens at exactly 65% screen height
          minChildSize: 0.40,     // Minimum drag collapse threshold
          maxChildSize: 0.90,     // Allows dragging almost to top screen edge
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF16161A), // Institutional dark grey hex theme
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Premium Grabber Bar indicator indicator
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Header Title Component
                  Text(
                    'Comments (${videoItem.commentCount})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  
                  // Core Comments List (Using placeholder for now)
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: videoItem.commentCount > 0 ? videoItem.commentCount : 1,
                      itemBuilder: (context, index) {
                        if (videoItem.commentCount == 0) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 64.0),
                              child: Text(
                                'Be the first to share your thoughts!',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ),
                          );
                        }
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFE2C55),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            'NigerGram Fan $index',
                            style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'This content is completely elite! Massive respect 🇳🇬🚀',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Bottom Text Field Input Area Base
                  Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      top: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Add a premium comment...',
                              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                              fillColor: const Color(0xFF26262B),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFFFE2C55)),
                          onPressed: () {
                            // Logic placeholder to attach database insertion pipeline
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // LAYER 1: Hardware Video Player Component Texture
        Positioned.fill(
          child: VideoFeedViewOptimizedVideoPlayer(
            controller: controller,
            videoId: videoItem.id,
          ),
        ),

        // LAYER 2: Non-interactive Vignette Shader Gradient
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black38,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black54,
                  ],
                  stops: [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        // LAYER 3: Interactive Left-Side Metadata Panel (Elevated to bottom: 16)
        Positioned(
          bottom: 16,
          left: 16,
          right: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  debugPrint('Navigate to profile of user: ${videoItem.username}');
                },
                child: Text(
                  '@${videoItem.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                videoItem.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.whiteECEF,
                  color: Color(0xFFE4E6EB),
                  fontSize: 14,
                  height: 1.3,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1))],
                ),
              ),
            ],
          ),
        ),

        // LAYER 4: Right-Side Floating Actions Dock Interceptor
        Positioned(
          bottom: 40, // Shifted upward so it sits elegantly higher than the navigation bar boundaries
          right: 12,
          child: VideoFeedViewInteractionButtons(
            videoId: videoItem.id,
            isLiked: videoItem.isLiked ?? false,
            likeCount: videoItem.likeCount,
            commentCount: videoItem.commentCount,
            shareCount: videoItem.shareCount,
            isBookmarked: videoItem.isBookmarked ?? false,
            creatorId: videoItem.creatorId,
            creatorUsername: videoItem.username,
            onCommentTapped: () => _openCommentsModalSheet(context), // Seamless sheet redirect trigger
            onShareTapped: () {
              debugPrint('Native distribution sheet initialization triggered');
            },
            onBookmarkTapped: () {
              debugPrint('Persisted compilation collection updated');
            },
          ),
        ),
      ],
    );
  }
}
