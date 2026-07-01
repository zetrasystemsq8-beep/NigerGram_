import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';
import 'video_feed_view_optimized_video_player.dart';

class VideoFeedViewItem extends StatefulWidget {
  final VideoEntity video;
  final VideoPlayerController controller;

  // Constructor expects 'videoItem' (to match parent), maps it to 'video'
  const VideoFeedViewItem({
    super.key,
    required VideoEntity videoItem,
    required this.controller,
  }) : video = videoItem;

  @override
  State<VideoFeedViewItem> createState() => _VideoFeedViewItemState();
}

class _VideoFeedViewItemState extends State<VideoFeedViewItem>
    with SingleTickerProviderStateMixin {
  bool _showOutro = false;
  late final VoidCallback _videoListener;

  // Animation controllers (created but NOT started yet)
  late final AnimationController _pulseController;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();

    // Create controllers but don't start them
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // Video listener
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
        // Start animations ONLY when outro appears
        _pulseController.repeat(reverse: true);
        _bounceController.repeat(reverse: true);
      }
    };

    widget.controller.addListener(_videoListener);
  }

  void _replayVideo() {
    // Stop animations when replaying
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
        // ONLY the optimized player. It internally creates the VideoPlayer widget
        // and handles buffering, fade-in, overlays, etc.
        VideoFeedViewOptimizedVideoPlayer(
          controller: widget.controller,
          videoId: widget.video.id,
        ),
        if (_showOutro) _buildOutroScreen(),
      ],
    );
  }

  Widget _buildOutroScreen() {
    return Semantics(
      button: true,
      label: 'Replay video',
      child: InkWell(
        onTap: _replayVideo,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          color: NGColors.background,
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing Logo with dynamic glow
                  _PulsingLogo(
                    pulseController: _pulseController,
                  ),
                  const SizedBox(height: 24),
                  // Slide-in Username (once, then stays readable)
                  TweenAnimationBuilder(
                    tween: Tween<Offset>(
                      begin: const Offset(-1.5, 0),
                      end: Offset.zero,
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, Offset offset, child) {
                      return Transform.translate(
                        offset: Offset(offset.dx * 150, 0),
                        child: Opacity(
                          opacity: offset.dx <= -0.5 ? 0 : 1,
                          child: Text(
                            '@${widget.video.username}',
                            style: TextStyle(
                              color: NGColors.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Bouncing replay text (with child optimization)
                  _BouncingReplayText(
                    bounceController: _bounceController,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 🔥 Extracted Widgets (Never rebuilt unnecessarily)
// ============================================================

class _PulsingLogo extends StatelessWidget {
  final AnimationController pulseController;

  const _PulsingLogo({
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    // Static logo child (never rebuilt)
    const logoChild = SizedBox(
      width: 80,
      height: 80,
      child: Icon(
        Icons.play_arrow,
        color: NGColors.accent,
        size: 50,
      ),
    );

    return AnimatedBuilder(
      animation: pulseController,
      child: logoChild,
      builder: (context, child) {
        final scale = 0.95 + (pulseController.value * 0.1);
        final glowIntensity = 0.15 + (pulseController.value * 0.2);
        final blurIntensity = 20 + (pulseController.value * 20);

        return Transform.scale(
          scale: scale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glowing ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NGColors.accent.withOpacity(
                      0.2 + (pulseController.value * 0.2),
                    ),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NGColors.accent.withOpacity(glowIntensity),
                      blurRadius: blurIntensity,
                      spreadRadius: 5 + (pulseController.value * 10),
                    ),
                  ],
                ),
              ),
              // Logo (reused, not rebuilt)
              child!,
            ],
          ),
        );
      },
    );
  }
}

class _BouncingReplayText extends StatelessWidget {
  final AnimationController bounceController;

  const _BouncingReplayText({
    required this.bounceController,
  });

  @override
  Widget build(BuildContext context) {
    // Static text child (never rebuilt)
    const replayText = Text(
      'Tap to replay',
      style: TextStyle(
        color: NGColors.textSecondary,
        fontSize: 14,
      ),
    );

    return AnimatedBuilder(
      animation: bounceController,
      child: replayText,
      builder: (context, child) {
        final scale = 1.0 + (bounceController.value * 0.03);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
    );
  }
}
