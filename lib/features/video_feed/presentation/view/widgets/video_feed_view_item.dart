// lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';
import 'video_feed_view_optimized_video_player.dart';
import 'video_feed_view_interaction_buttons.dart';
import 'comments_viewer_bottom_sheet.dart';
import 'video_feed_view_description_text.dart';
import 'package:share_plus/share_plus.dart';

class VideoFeedViewItem extends StatefulWidget {
  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  const VideoFeedViewItem({
    super.key,
    required this.videoItem,
    required this.controller,
  });

  @override
  State<VideoFeedViewItem> createState() => _VideoFeedViewItemState();
}

class _VideoFeedViewItemState extends State<VideoFeedViewItem> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.videoItem.isLiked ?? false;
    _likeCount = widget.videoItem.likeCount ?? 0;
  }

  /// 📥 THE REAL-TIME NIGERGRAM COMMENT ENGINE MODAL
  void _openCommentsModalSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return CommentsViewerBottomSheet(videoId: widget.videoItem.id);
      },
    );
  }

  /// 🔗 Use native share sheet via share_plus
  Future<void> _executePlatformShareAction(BuildContext context) async {
    HapticFeedback.lightImpact();

    final String? videoId = widget.videoItem.id;
    final String? creator = widget.videoItem.username;
    final String videoUrl = (videoId != null && videoId.isNotEmpty)
        ? 'https://nigergram.app/video/$videoId'
        : '';

    final bool hasUrl = videoUrl.isNotEmpty;
    final String subject = (creator != null && creator.isNotEmpty) ? '@$creator on NigerGram' : 'NigerGram';
    final String content = hasUrl
        ? 'Watch this on NigerGram: $videoUrl'
        : 'Check out this video on NigerGram!';

    try {
      await Share.share(content, subject: subject);
    } catch (error) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Could not share the video. Please try again.'),
        ),
      );
    }
  }

  void _handleDoubleTapLike(String videoId) {
    HapticFeedback.selectionClick();

    // Optimistically update UI
    if (!_isLiked) {
      setState(() {
        _isLiked = true;
        _likeCount = _likeCount + 1;
      });
    }

    // TODO: Call backend like endpoint or analytics here.
    debugPrint('Double-tap like triggered for video: $videoId');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // LAYER 1: Hardware Video Player Component Texture
        Positioned.fill(
          child: VideoFeedViewOptimizedVideoPlayer(
            controller: widget.controller,
            videoId: widget.videoItem.id,
            creatorUsername: widget.videoItem.username,
            onDoubleTapLike: (id) => _handleDoubleTapLike(id),
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
                    Colors.black45,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.2, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),

        // LAYER 3: Interactive Left-Side Metadata Panel
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
                  HapticFeedback.lightImpact();
                  context.push('/profile/${widget.videoItem.creatorId}');
                },
                child: Text(
                  '@${widget.videoItem.username}',
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

              // Use the enhanced description text widget that supports hashtags and mentions
              VideoFeedViewDescriptionText(text: widget.videoItem.description),
            ],
          ),
        ),

        // LAYER 4: Right-Side Floating Actions Dock Interceptor
        Positioned(
          bottom: 40,
          right: 12,
          child: VideoFeedViewInteractionButtons(
            videoId: widget.videoItem.id,
            isLiked: _isLiked,
            likeCount: _likeCount,
            commentCount: widget.videoItem.commentCount,
            shareCount: widget.videoItem.shareCount,
            isBookmarked: widget.videoItem.isBookmarked ?? false,
            creatorId: widget.videoItem.creatorId,
            creatorUsername: widget.videoItem.username,
            onCommentTapped: () => _openCommentsModalSheet(context),
            onShareTapped: () => _executePlatformShareAction(context),
            onBookmarkTapped: () {
              HapticFeedback.selectionClick();
            },
            onLikeTapped: () {
              // Keep the interaction buttons functional if they also support liking
              _handleDoubleTapLike(widget.videoItem.id ?? '');
            },
          ),
        ),
      ],
    );
  }
}
