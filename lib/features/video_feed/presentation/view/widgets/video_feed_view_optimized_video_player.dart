// lib/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
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

  // UI-only animation controllers
  late AnimationController _videoFadeController;
  late Animation<double> _videoFadeAnimation;
  late AnimationController _bufferFadeController;
  late AnimationController _doubleTapHeartController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  late Animation<double> _heartRotationAnimation;
  late AnimationController _logoLoaderController;

  bool _isBuffering = false;
  VideoPlayerController? _oldController;
  String? _currentVideoId;
  bool _isPlaying = false;

  bool _showPlayIconOverlay = false;
  IconData _overlayIconData = Icons.play_arrow_rounded;

  bool _showHeart = false;

  // Track initialization state
  bool _isControllerInitialized = false;
  bool _isInitializing = false;

  // ✅ Progress bar state (NO heatmap)
  bool _isScrubbing = false;
  Duration _scrubPosition = Duration.zero;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    
    _actionIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Smooth video fade-in once ready
    _videoFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _videoFadeAnimation = CurvedAnimation(
      parent: _videoFadeController,
      curve: Curves.easeOut,
    );

    // Buffering glass loader fade
    _bufferFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Double tap heart animation
    _doubleTapHeartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_doubleTapHeartController);
    _heartOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_doubleTapHeartController);
    _heartRotationAnimation = Tween<double>(begin: -0.15, end: 0.08).animate(
      CurvedAnimation(parent: _doubleTapHeartController, curve: Curves.easeOut),
    );

    // Premium logo loader rotation/pulse
    _logoLoaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _oldController = widget.controller;
    _currentVideoId = widget.videoId;
    
    _checkAndSetupController();

    // Auto-hide controls after 3 seconds
    _startControlsTimer();
  }

  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isScrubbing) {
        setState(() => _showControls = false);
      }
    });
  }

  void _checkAndSetupController() {
    final controller = widget.controller;
    if (controller == null) {
      setState(() {
        _isControllerInitialized = false;
        _isInitializing = false;
      });
      return;
    }

    if (controller.value.isInitialized) {
      _setupController(controller);
    } else {
      setState(() {
        _isInitializing = true;
        _isControllerInitialized = false;
      });
      
      controller.addListener(_onControllerInitListener);
    }
  }

  void _onControllerInitListener() {
    final controller = widget.controller;
    if (controller == null) return;
    
    if (controller.value.isInitialized) {
      controller.removeListener(_onControllerInitListener);
      if (mounted) {
        _setupController(controller);
      }
    }
  }

  void _setupController(VideoPlayerController controller) {
    _oldController?.removeListener(_onControllerUpdate);
    _oldController?.removeListener(_onControllerInitListener);
    
    _oldController = controller;
    _isControllerInitialized = true;
    _isInitializing = false;
    
    _applyLowDataOptimization(controller);
    _addControllerListener(controller);
    
    _ensureAutoplay(controller);

    _videoFadeController.forward(from: 0.0);
    
    if (mounted) {
      setState(() {});
    }
  }

  void _ensureAutoplay(VideoPlayerController controller) {
    if (controller.value.isInitialized) {
      if (!controller.value.isPlaying) {
        controller.play();
      }
    }
  }

  void _applyLowDataOptimization(VideoPlayerController controller) {
    if (controller.value.isInitialized) {
      controller.setLooping(true);
      controller.setVolume(1.0);
    }
  }

  void _addControllerListener(VideoPlayerController controller) {
    controller.removeListener(_onControllerUpdate);
    controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(VideoFeedViewOptimizedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool videoIdChanged = widget.videoId != _currentVideoId;
    final bool controllerChanged = widget.controller != _oldController;

    if (videoIdChanged || controllerChanged) {
      _oldController?.removeListener(_onControllerUpdate);
      _oldController?.removeListener(_onControllerInitListener);
      
      _oldController = widget.controller;
      _currentVideoId = widget.videoId;
      // ✅ FIX: no longer reassigning a UniqueKey here. Regenerating a
      // UniqueKey on every page change forced Flutter to treat the
      // FittedBox/VideoPlayer subtree as a brand new widget on every
      // swipe while it was live inside the PageView's sliver tree —
      // this was the second, more frequent trigger of the
      // "'child == _child': is not true" crash.
      _isBuffering = false;

      _videoFadeController.reset();
      
      _checkAndSetupController();
      _startControlsTimer();
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _actionIconAnimationController.dispose();
    _videoFadeController.dispose();
    _bufferFadeController.dispose();
    _doubleTapHeartController.dispose();
    _logoLoaderController.dispose();
    _oldController?.removeListener(_onControllerUpdate);
    _oldController?.removeListener(_onControllerInitListener);
    _oldController = null;
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final controller = widget.controller;
    if (controller == null) return;
    if (widget.videoId != _currentVideoId) return;

    if (!controller.value.isInitialized) {
      if (mounted) {
        setState(() {
          _isControllerInitialized = false;
          _isBuffering = false;
        });
      }
      return;
    }

    if (!_isControllerInitialized) {
      if (mounted) {
        setState(() {
          _isControllerInitialized = true;
          _isInitializing = false;
        });
      }
    }

    if (controller.value.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isBuffering = false);
      });
      return;
    }

    final isBuffering = controller.value.isBuffering;
    final isPlaying = controller.value.isPlaying;

    bool shouldShowBuffering = isBuffering && isPlaying;

    if (_isBuffering != shouldShowBuffering || _isPlaying != isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isBuffering = shouldShowBuffering;
            _isPlaying = isPlaying;
          });
          if (shouldShowBuffering) {
            _bufferFadeController.forward();
          } else {
            _bufferFadeController.reverse();
          }
        }
      });
    }

    // Update progress bar if not scrubbing
    if (!_isScrubbing && mounted) {
      setState(() {});
    }
  }

  void _handleSingleTapToggle() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    HapticFeedback.lightImpact();

    // Show controls on tap
    setState(() => _showControls = true);
    _startControlsTimer();

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
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _showPlayIconOverlay = false);
        }
      });
    });
  }

  void _handleDoubleTapLike() {
    HapticFeedback.mediumImpact();
    setState(() => _showHeart = true);
    _doubleTapHeartController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // PREMIUM UI BUILDERS
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildPremiumLoader() {
    return Container(
      color: Colors.black,
      child: Center(
        child: AnimatedBuilder(
          animation: _logoLoaderController,
          builder: (context, child) {
            final t = _logoLoaderController.value;
            final pulse = 0.85 + (math.sin(t * 2 * math.pi) * 0.08);
            return Opacity(
              opacity: 1.0,
              child: Transform.scale(
                scale: pulse,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _logoLoaderController,
                    child: Container(
                      width: context.sq(56),
                      height: context.sq(56),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            NGColors.accent.withOpacity(0.0),
                            NGColors.accent,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: context.sq(48),
                          height: context.sq(48),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white.withOpacity(0.95),
                    size: context.sq(26),
                  ),
                ],
              ),
              SizedBox(height: context.h(16)),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: context.fontSize(13),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBufferingLoader() {
    return Center(
      child: AnimatedBuilder(
        animation: _bufferFadeController,
        builder: (context, child) {
          return Opacity(
            opacity: _bufferFadeController.value,
            child: Transform.scale(
              scale: 0.85 + (_bufferFadeController.value * 0.15),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: context.sq(64),
              height: context.sq(64),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: NGColors.accent.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _actionIconAnimationController,
        builder: (context, child) {
          final double scaleFactor = TweenSequence<double>([
            TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 70),
            TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 30),
          ]).evaluate(_actionIconAnimationController);

          final double opacityFactor = TweenSequence<double>([
            TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.9), weight: 40),
            TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 60),
          ]).evaluate(_actionIconAnimationController);

          final double rippleScale = TweenSequence<double>([
            TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 1.6).chain(CurveTween(curve: Curves.easeOut)), weight: 100),
          ]).evaluate(_actionIconAnimationController);
          final double rippleOpacity = TweenSequence<double>([
            TweenSequenceItem(tween: Tween<double>(begin: 0.35, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 100),
          ]).evaluate(_actionIconAnimationController);

          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: rippleOpacity,
                child: Transform.scale(
                  scale: rippleScale,
                  child: Container(
                    width: context.sq(90),
                    height: context.sq(90),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: opacityFactor,
                child: Transform.scale(
                  scale: scaleFactor,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(48),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _overlayIconData,
                          color: Colors.white,
                          size: context.sq(46),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDoubleTapHeart() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _doubleTapHeartController,
        builder: (context, child) {
          return Opacity(
            opacity: _heartOpacityAnimation.value,
            child: Transform.scale(
              scale: _heartScaleAnimation.value,
              child: Transform.rotate(
                angle: _heartRotationAnimation.value,
                child: child,
              ),
            ),
          );
        },
        child: Icon(
          Icons.favorite_rounded,
          color: NGColors.accent,
          size: context.sq(110),
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.w(32)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: context.h(32),
                  horizontal: context.w(24),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NGColors.accent.withOpacity(0.12),
                        border: Border.all(
                          color: NGColors.accent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        color: NGColors.accent,
                        size: context.sq(36),
                      ),
                    ),
                    SizedBox(height: context.h(20)),
                    Text(
                      'Unable to load video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.fontSize(16),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: context.h(6)),
                    Text(
                      'Check your internet connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: context.fontSize(13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: context.h(24)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.controller?.initialize().then((_) {
                            if (mounted) {
                              _ensureAutoplay(widget.controller!);
                              setState(() {});
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NGColors.accent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: context.h(14),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: context.sq(18)),
                            SizedBox(width: context.w(8)),
                            Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: context.fontSize(15),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // ✅ PROGRESS BAR + SCRUBBER + TIME DISPLAY
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final duration = controller.value.duration;
    if (duration == Duration.zero) {
      return const SizedBox.shrink();
    }

    final position = _isScrubbing ? _scrubPosition : controller.value.position;
    final progress = position.inMilliseconds / duration.inMilliseconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          onTapDown: (details) {
            final pos = (details.localPosition.dx / width).clamp(0.0, 1.0);
            _scrubPosition = Duration(milliseconds: (duration.inMilliseconds * pos).round());
            controller.seekTo(_scrubPosition);
            setState(() {});
          },
          onTapUp: (_) {
            controller.play();
            _startControlsTimer();
          },
          onHorizontalDragStart: (_) {
            _isScrubbing = true;
            setState(() => _showControls = true);
            controller.pause();
          },
          onHorizontalDragUpdate: (details) {
            final pos = (details.localPosition.dx / width).clamp(0.0, 1.0);
            _scrubPosition = Duration(milliseconds: (duration.inMilliseconds * pos).round());
            controller.seekTo(_scrubPosition);
            setState(() {});
          },
          onHorizontalDragEnd: (_) {
            _isScrubbing = false;
            controller.play();
            setState(() {});
            _startControlsTimer();
          },
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                // Played portion
                Container(
                  width: (width * progress.clamp(0.0, 1.0)),
                  height: 4,
                  decoration: BoxDecoration(
                    color: NGColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Scrubber dot
                if (_isScrubbing || controller.value.isPlaying)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(left: -6),
                    decoration: BoxDecoration(
                      color: NGColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeDisplay() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final duration = controller.value.duration;
    if (duration == Duration.zero) {
      return const SizedBox.shrink();
    }

    final position = _isScrubbing ? _scrubPosition : controller.value.position;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatDuration(position),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          _formatDuration(duration),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    final bool isNotReady = controller == null || 
                           !controller.value.isInitialized || 
                           _isInitializing;

    if (isNotReady) {
      return _buildPremiumLoader();
    }

    return GestureDetector(
      onTap: _handleSingleTapToggle,
      onDoubleTap: _handleDoubleTapLike,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video player with fade-in
          Positioned.fill(
            child: FadeTransition(
              opacity: _videoFadeAnimation,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),

          // Play/Pause overlay
          if (_showPlayIconOverlay) _buildPlayPauseOverlay(),

          // Double tap heart
          if (_showHeart) _buildDoubleTapHeart(),

          // Buffering loader
          if (_isBuffering && _isControllerInitialized) _buildBufferingLoader(),

          // Error state
          if (controller.value.hasError) _buildErrorState(),

          // ✅ Bottom controls: Progress bar + Time
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProgressBar(),
                    const SizedBox(height: 4),
                    _buildTimeDisplay(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
