// lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart

import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';
import 'video_feed_view_optimized_video_player.dart';
import 'video_action_buttons.dart'; // ✅ Make sure this file exists

class VideoFeedViewItem extends StatefulWidget {
  final VideoEntity video;
  final VideoPlayerController controller;

  // ✅ ADD THESE CALLBACKS
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const VideoFeedViewItem({
    super.key,
    required VideoEntity videoItem,
    required this.controller,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  }) : video = videoItem;

  @override
  State<VideoFeedViewItem> createState() => _VideoFeedViewItemState();
}

class _VideoFeedViewItemState extends State<VideoFeedViewItem>
    with SingleTickerProviderStateMixin {
  bool _showOutro = false;
  late final VoidCallback _videoListener;

  late final AnimationController _pulseController;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _videoListener = () {
      if (!widget.controller.value.isInitialized) return;

      final value = widget.controller.value;

      final isAtEnd = value.duration != Duration.zero &&
          value.position >= value.duration - const Duration(milliseconds: 200);

      if (!mounted) return;

      if (isAtEnd && !value.isPlaying && !_showOutro) {
        setState(() {
          _showOutro = true;
        });
        _pulseController.repeat(reverse: true);
        _bounceController.repeat(reverse: true);
      }
    };

    widget.controller.addListener(_videoListener);
  }

  void _replayVideo() {
    _pulseController.stop();
    _bounceController.stop();
    _pulseController.reset();
    _bounceController.reset();

    setState(() {
      _showOutro = false;
    });
    widget.controller.seekTo(Duration.zero);
    widget.controller.play();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VideoPlayer(widget.controller),
        VideoFeedViewOptimizedVideoPlayer(
          controller: widget.controller,
          videoId: widget.video.id,
        ),

        // ✅ Action Buttons – now using the passed callbacks
        VideoActionButtons(
          videoUrl: widget.video.videoUrl,
          videoId: widget.video.id,
          username: widget.video.username,
          likeCount: widget.video.likeCount ?? 0,
          isLiked: widget.video.isLiked ?? false,
          onLike: widget.onLike,
          onComment: widget.onComment,
          onShare: widget.onShare,
        ),

        if (_showOutro) _buildOutroScreen(),
      ],
    );
  }

  // ... (rest of the file unchanged: _buildOutroScreen, _PulsingLogo, _BouncingReplayText)
}
