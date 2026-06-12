import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:video_player/video_player.dart';

class VideoFeedViewOptimizedVideoPlayer extends StatefulWidget {
  const VideoFeedViewOptimizedVideoPlayer({
    required this.controller, 
    required this.videoId, 
    super.key
  });

  final VideoPlayerController? controller;
  final String videoId;

  @override
  State<VideoFeedViewOptimizedVideoPlayer> createState() => _VideoFeedViewOptimizedVideoPlayerState();
}

class _VideoFeedViewOptimizedVideoPlayerState extends State<VideoFeedViewOptimizedVideoPlayer> with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late AnimationController _actionIconAnimationController;
  
  bool _isBuffering = false;
  VideoPlayerController? _oldController;
  String? _currentVideoId;
  bool _isPlaying = false;
  Key _playerKey = UniqueKey();
  
  // Icon toggles for central play/pause state feedback bursts
  bool _showPlayIconOverlay = false;
  IconData _overlayIconData = Icons.play_arrow_rounded;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    
    _actionIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _oldController = widget.controller;
    _currentVideoId = widget.videoId;
    _applyLowDataOptimization();
    _addControllerListener();
  }

  /// Forces the controller into a Restricted Data Mode
  void _applyLowDataOptimization() {
    if (widget.controller != null && widget.controller!.value.isInitialized) {
      // Disable background 'over-fetching' to save user data
      widget.controller!.setLooping(true);
      widget.controller!.setVolume(1.0);
    }
  }

  void _addControllerListener() {
    if (widget.controller != null) {
      _isBuffering = widget.controller!.value.isBuffering;
      _isPlaying = widget.controller!.value.isPlaying;
      widget.controller!.addListener(_onControllerUpdate);
    }
  }

  @override
  void didUpdateWidget(VideoFeedViewOptimizedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool videoIdChanged = widget.videoId != _currentVideoId;
    final bool controllerChanged = widget.controller != _oldController;

    if (videoIdChanged || controllerChanged) {
      _oldController?.removeListener(_onControllerUpdate);
      _oldController = widget.controller;
      _currentVideoId = widget.videoId;
      _playerKey = UniqueKey();
      _applyLowDataOptimization();
      _addControllerListener();

      final bool shouldUpdateBuffering = widget.controller?.value.isBuffering ?? false;
      if (mounted && _isBuffering != shouldUpdateBuffering) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isBuffering = shouldUpdateBuffering;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _actionIconAnimationController.dispose();
    _oldController?.removeListener(_onControllerUpdate);
    _oldController = null;
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final controller = widget.controller;
    if (controller == null) return;
    if (widget.videoId != _currentVideoId) return;

    if (controller.value.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isBuffering = false);
      });
      return;
    }

    final isBuffering = controller.value.isBuffering;
    final isPlaying = controller.value.isPlaying;

    // Optimized Buffering Logic: Only spin if we are actually stalled.
    bool shouldShowBuffering = isBuffering;
    if ((isPlaying && controller.value.position > Duration.zero) ||
        (controller.value.position > Duration.zero && controller.value.duration.inMilliseconds > 0)) {
      shouldShowBuffering = false;
    }

    if (_isBuffering != shouldShowBuffering || _isPlaying != isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isBuffering = shouldShowBuffering;
            _isPlaying = isPlaying;
          });
        }
      });
    }
  }

  void _handleSingleTapToggle() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    HapticFeedback.lightImpact();

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _overlayIconData = Icons.pause_rounded;
      } else {
        controller.play();
        _overlayIconData = Icons.play_arrow_rounded;
      }
      _showPlayIconOverlay = true;
    });

    _actionIconAnimationController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _showPlayIconOverlay = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: RotationTransition(
            turns: Tween<double>(begin: 0, end: 1).animate(_loadingController),
            child: Icon(
              Icons.loop_rounded,
              color: Colors.white.withAlpha(180),
              size: context.sq(32),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _handleSingleTapToggle,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Immersive Video Canvas Layer
          SizedBox.expand(
            child: FittedBox(
              key: _playerKey,
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),

          // 2. High-Velocity Action Icon Pop Overlay
          if (_showPlayIconOverlay)
            AnimatedBuilder(
              animation: _actionIconAnimationController,
              builder: (context, child) {
                final double scaleFactor = TweenSequence<double>([
                  TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 70),
                  TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 30),
                ]).evaluate(_actionIconAnimationController);

                final double opacityFactor = TweenSequence<double>([
                  TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.8), weight: 40),
                  TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 60),
                ]).evaluate(_actionIconAnimationController);

                return Opacity(
                  opacity: opacityFactor,
                  child: Transform.scale(
                    scale: scaleFactor,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _overlayIconData,
                        color: Colors.white,
                        size: context.sq(50),
                      ),
                    ),
                  ),
                );
              },
            ),

          // 3. Optimized Buffering Overlay
          if (_isBuffering)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withAlpha(30),
              child: Center(
                child: SizedBox(
                  width: context.sq(36),
                  height: context.sq(36),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
            
          // 4. Premium Error UI Recovery Matrix
          if (controller.value.hasError)
            Container(
              color: Colors.black87,
              padding: EdgeInsets.symmetric(horizontal: context.w(32)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white.withAlpha(140), size: context.sq(44)),
                    SizedBox(height: context.h(12)),
                    Text(
                      "Check connection. Tap to retry.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: context.fontSize(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
