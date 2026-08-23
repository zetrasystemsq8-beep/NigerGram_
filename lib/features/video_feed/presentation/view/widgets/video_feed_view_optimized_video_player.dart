// lib/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:video_player/video_player.dart';

/// Fixed default caption shown on every video — the "Day 1" style tag
/// RedNote uses, reframed around the app's own brand word. Kept as a
/// function (rather than a bare constant) so the caption logic in the
/// widget below doesn't need to change if this ever becomes dynamic again.
String taglineForVideo(String videoId) => '🤝 Connect';

/// The spoken "Connect" voice clip, bundled as an asset. Played once each
/// time a video completes a full playthrough, alongside the end-of-video
/// overlay below — this is the app's own audio identity, the equivalent
/// of RedNote's spoken tag or TikTok's between-video transition sound.
const String kEndOfVideoAudioAsset = 'sounds/zetra_spoken.wav';

class VideoFeedViewOptimizedVideoPlayer extends StatefulWidget {
  const VideoFeedViewOptimizedVideoPlayer({
    required this.controller,
    required this.videoId,
    this.creatorUsername,
    super.key,
  });

  final VideoPlayerController? controller;
  final String videoId;

  /// Shown alongside the default tagline, e.g. "@zetra_dev".
  /// Optional so this widget doesn't break if a caller doesn't pass it.
  final String? creatorUsername;

  @override
  State<VideoFeedViewOptimizedVideoPlayer> createState() => _VideoFeedViewOptimizedVideoPlayerState();
}

class _VideoFeedViewOptimizedVideoPlayerState extends State<VideoFeedViewOptimizedVideoPlayer> with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late AnimationController _actionIconAnimationController;
  late AudioPlayer _endOfVideoAudioPlayer;

  bool _isBuffering = false;
  VideoPlayerController? _oldController;
  String? _currentVideoId;
  bool _isPlaying = false;
  Key _playerKey = UniqueKey();
  
  bool _showPlayIconOverlay = false;
  IconData _overlayIconData = Icons.play_arrow_rounded;
  
  // 🔥 FIX: Track initialization state separately
  bool _isControllerInitialized = false;
  bool _isInitializing = false;

  // End-of-video branded overlay (logo + loading bar + Connect/username
  // caption), shown briefly each time the video completes a loop —
  // mirrors TikTok's between-video transition moment.
  bool _showEndOfVideoOverlay = false;
  Duration _lastKnownPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    
    _actionIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _endOfVideoAudioPlayer = AudioPlayer();

    _oldController = widget.controller;
    _currentVideoId = widget.videoId;
    
    // 🔥 FIX: Check if controller is already initialized
    _checkAndSetupController();
  }

  // 🔥 FIX: New method to handle controller setup with proper state
  void _checkAndSetupController() {
    final controller = widget.controller;
    if (controller == null) {
      setState(() {
        _isControllerInitialized = false;
        _isInitializing = false;
      });
      return;
    }

    // If controller is already initialized, set up immediately
    if (controller.value.isInitialized) {
      _setupController(controller);
    } else {
      // If not initialized, wait for it
      setState(() {
        _isInitializing = true;
        _isControllerInitialized = false;
      });
      
      // Add listener to catch when initialization completes
      controller.addListener(_onControllerInitListener);
    }
  }

  // 🔥 FIX: Separate listener for initialization
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

  // 🔥 FIX: Setup controller once initialized
  void _setupController(VideoPlayerController controller) {
    // Remove any old listeners
    _oldController?.removeListener(_onControllerUpdate);
    _oldController?.removeListener(_onControllerInitListener);
    
    _oldController = controller;
    _isControllerInitialized = true;
    _isInitializing = false;
    _lastKnownPosition = Duration.zero;
    
    _applyLowDataOptimization(controller);
    _addControllerListener(controller);
    
    // Play immediately
    _ensureAutoplay(controller);
    
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
      // Clean up old controller listeners
      _oldController?.removeListener(_onControllerUpdate);
      _oldController?.removeListener(_onControllerInitListener);
      
      _oldController = widget.controller;
      _currentVideoId = widget.videoId;
      _playerKey = UniqueKey();
      _isBuffering = false;
      _showEndOfVideoOverlay = false;
      _lastKnownPosition = Duration.zero;
      
      // 🔥 FIX: Re-check controller setup
      _checkAndSetupController();
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _actionIconAnimationController.dispose();
    _endOfVideoAudioPlayer.dispose();
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

    // 🔥 FIX: Check for initialization
    if (!controller.value.isInitialized) {
      if (mounted) {
        setState(() {
          _isControllerInitialized = false;
          _isBuffering = false;
        });
      }
      return;
    }

    // Update initialized state if needed
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

    // 🔥 FIX: Only show buffering if playing and buffer is loading
    bool shouldShowBuffering = isBuffering && isPlaying;

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

    _checkForVideoEnd(controller);
  }

  /// Detects a completed playthrough the same way the parent feed's own
  /// loop-tracking does — position crosses close to duration, then wraps
  /// back down near zero on the next tick (since looping is enabled).
  /// When that happens: fire the branded overlay + the spoken audio cue.
  void _checkForVideoEnd(VideoPlayerController controller) {
    if (!controller.value.isPlaying) return;

    final pos = controller.value.position;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return;

    final wasNearEnd = _lastKnownPosition >= duration - const Duration(milliseconds: 250);
    final wrappedToStart = pos.inMilliseconds < 400;

    if (wasNearEnd && wrappedToStart && !_showEndOfVideoOverlay) {
      _triggerEndOfVideoMoment();
    }

    _lastKnownPosition = pos;
  }

  Future<void> _triggerEndOfVideoMoment() async {
    if (!mounted) return;

    setState(() => _showEndOfVideoOverlay = true);

    try {
      await _endOfVideoAudioPlayer.stop();
      await _endOfVideoAudioPlayer.play(AssetSource(kEndOfVideoAudioAsset));
    } catch (e) {
      debugPrint('End-of-video audio failed to play: $e');
    }

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() => _showEndOfVideoOverlay = false);
      }
    });
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
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _showPlayIconOverlay = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    // 🔥 FIX: More comprehensive initialization check
    final bool isNotReady = controller == null || 
                           !controller.value.isInitialized || 
                           _isInitializing;

    if (isNotReady) {
      return Container(
        color: Colors.black,
        child: Center(
          child: _NigerGramSpinner(controller: _loadingController, size: context.sq(46)),
        ),
      );
    }

    return GestureDetector(
      onTap: _handleSingleTapToggle,
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hardware Accelerated Media View Box
          Positioned.fill(
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

          // Scale and Fade Animation Play/Pause Overlay Engine
          if (_showPlayIconOverlay)
            IgnorePointer(
              child: AnimatedBuilder(
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
            ),

          // Low-Data Buffering Spin Segment — now brand-styled instead of default
          if (_isBuffering && _isControllerInitialized)
            Center(
              child: _NigerGramSpinner(controller: _loadingController, size: context.sq(34)),
            ),
            
          // Connection Error State Layer
          if (controller.value.hasError)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white.withAlpha(140), size: context.sq(44)),
                    SizedBox(height: context.h(12)),
                    Text(
                      "Check connection. Tap to retry.",
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

          // Persistent tagline + creator caption — the "Day 1" style tag,
          // reframed for a builder feed. Sits near the top so it never
          // collides with the username/description block anchored at
          // the bottom of VideoFeedViewItem.
          Positioned(
            top: context.h(12),
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.creatorUsername != null && widget.creatorUsername!.isNotEmpty
                        ? '${taglineForVideo(widget.videoId)}  ·  @${widget.creatorUsername}'
                        : taglineForVideo(widget.videoId),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: context.fontSize(12),
                      fontWeight: FontWeight.w600,
                      shadows: const [Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // End-of-video branded transition overlay — the TikTok-style
          // "between videos" moment: wordmark + animated loading bar +
          // the same Connect/username caption, shown briefly and faded
          // out. Paired with the spoken audio cue triggered above.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showEndOfVideoOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: Container(
                color: Colors.black.withOpacity(0.88),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NigerGram',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.fontSize(24),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: context.h(18)),
                      _EndOfVideoLoadingBar(controller: _loadingController),
                      SizedBox(height: context.h(18)),
                      Text(
                        widget.creatorUsername != null && widget.creatorUsername!.isNotEmpty
                            ? '${taglineForVideo(widget.videoId)}  ·  @${widget.creatorUsername}'
                            : taglineForVideo(widget.videoId),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: context.fontSize(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded loading spinner — replaces the default Flutter spinner/loop icon
/// with a NigerGram-accent-colored rotating arc, matching the story-ring
/// visual language already used on the profile screen.
class _NigerGramSpinner extends StatelessWidget {
  const _NigerGramSpinner({required this.controller, required this.size});

  final AnimationController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Transform.rotate(
          angle: controller.value * 6.28318530718, // 2 * pi
          child: CustomPaint(
            size: Size(size, size),
            painter: _BrandArcSpinnerPainter(color: NGColors.accent),
          ),
        );
      },
    );
  }
}

class _BrandArcSpinnerPainter extends CustomPainter {
  _BrandArcSpinnerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final trackPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    const startAngle = -1.5707963268; // -90deg, start at top
    const sweepAngle = 4.18879020479; // ~240deg arc

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandArcSpinnerPainter oldDelegate) => oldDelegate.color != color;
}

/// The horizontal loading-bar animation shown inside the end-of-video
/// overlay — a rounded track with a colored pill sweeping across it,
/// styled with the same red/cyan pairing already used on the Dashboard's
/// upload button, so the app's visual identity stays consistent.
class _EndOfVideoLoadingBar extends StatelessWidget {
  const _EndOfVideoLoadingBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    const double trackWidth = 160;
    const double pillWidth = 56;

    return SizedBox(
      width: trackWidth,
      height: 10,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              // Sweeps left-to-right and back, matching TikTok Lite's
              // between-video bar rather than a one-shot progress fill.
              final t = controller.value;
              final progress = t < 0.5 ? (t * 2) : (2 - t * 2);
              final left = progress * (trackWidth - pillWidth);

              return Positioned(
                left: left,
                child: Container(
                  width: pillWidth,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFE2C55), Color(0xFF23F6E4)],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
