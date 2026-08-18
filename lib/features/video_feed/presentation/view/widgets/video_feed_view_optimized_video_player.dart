// lib/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:video_player/video_player.dart';

/// Fixed default caption shown on every video — the "Day 1" style tag
/// RedNote uses, reframed around the app's own brand word. Kept as a
/// function (rather than a bare constant) so the caption logic in the
/// widget below doesn't need to change if this ever becomes dynamic again.
String taglineForVideo(String videoId) => '🤝 Connect';

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

  // --- Branded outro shown between every loop of a video ---
  // When the creator's video reaches its end, instead of just silently
  // looping (setLooping(true) below), we pause it, show a 4-second
  // branded clip full-screen with narration audio playing over it, then
  // once that finishes, seek the creator's video back to 0 and resume
  // normal playback. Every video gets this treatment, every time it
  // finishes — not just the very last video in the feed.
  static const String _outroVideoAsset = 'assets/sounds/lv_732853827814200487_20260818020652.mp4';
  static const String _narrationAsset = 'sounds/zetra_spoken.wav';

  VideoPlayerController? _outroController;
  final AudioPlayer _narrationPlayer = AudioPlayer();
  bool _showingOutro = false;
  bool _outroControllerReady = false;

  Duration? _lastKnownPosition;
  static const _loopEndProximity = Duration(milliseconds: 400);
  static const _loopRestartJump = Duration(milliseconds: 500);

  Future<void> _ensureOutroControllerReady() async {
    if (_outroControllerReady) return;
    final outro = VideoPlayerController.asset(_outroVideoAsset);
    try {
      await outro.initialize();
      await outro.setLooping(false);
      // Muted — narration comes from the separate wav file, played
      // alongside it, not from the outro clip's own audio track.
      await outro.setVolume(0);
      _outroController = outro;
      _outroControllerReady = true;
    } catch (_) {
      // If the outro clip fails to load, we simply skip the outro step
      // entirely later (see _playOutroThenResume) rather than get stuck.
      _outroControllerReady = false;
    }
  }

  Future<void> _playOutroThenResume(VideoPlayerController mainController) async {
    if (_showingOutro) return; // already mid-outro, don't double-trigger

    mainController.pause();

    await _ensureOutroControllerReady();
    final outro = _outroController;

    if (!mounted) return;

    if (outro == null || !_outroControllerReady) {
      // Outro clip unavailable — just play the narration alone over the
      // frozen frame, briefly, rather than get stuck forever.
      try {
        await _narrationPlayer.stop();
        await _narrationPlayer.play(AssetSource(_narrationAsset));
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
      _resumeMainVideo(mainController);
      return;
    }

    setState(() => _showingOutro = true);

    await outro.seekTo(Duration.zero);
    await outro.play();

    try {
      await _narrationPlayer.stop();
      await _narrationPlayer.play(AssetSource(_narrationAsset));
    } catch (_) {
      // Never let narration failure block the visual outro.
    }

    void onOutroTick() {
      if (!mounted) return;
      final value = outro.value;
      if (!value.isInitialized) return;
      final duration = value.duration;
      if (duration.inMilliseconds > 0 &&
          value.position >= duration - const Duration(milliseconds: 150)) {
        outro.removeListener(onOutroTick);
        _resumeMainVideo(mainController);
      }
    }

    outro.addListener(onOutroTick);
  }

  void _resumeMainVideo(VideoPlayerController mainController) {
    if (!mounted) return;
    setState(() => _showingOutro = false);
    _lastKnownPosition = null;
    mainController.seekTo(Duration.zero).then((_) {
      if (mounted) mainController.play();
    });
  }

  void _checkForLoopRestart(VideoPlayerController controller) {
    if (_showingOutro) return;

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration <= Duration.zero) return;

    final lastPosition = _lastKnownPosition;
    if (lastPosition != null &&
        lastPosition >= (duration - _loopEndProximity) &&
        position < (lastPosition - _loopRestartJump)) {
      _playOutroThenResume(controller);
      return;
    }

    _lastKnownPosition = position;
  }
  // --- end outro logic ---

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

    // Reset outro/loop-detection state for the new video — otherwise a
    // stale position or an in-flight outro from the previous video
    // could carry over incorrectly.
    _lastKnownPosition = null;
    _showingOutro = false;
    
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
      // Looping stays OFF at the platform level now — looping is instead
      // driven manually by _resumeMainVideo() after each outro finishes,
      // so every "loop" reliably passes through the outro step first.
      controller.setLooping(false);
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

      // Swiped to a different video — cancel any in-progress outro for
      // the previous one so it doesn't resume the wrong controller later.
      _outroController?.pause();
      _narrationPlayer.stop();
      _showingOutro = false;
      
      // 🔥 FIX: Re-check controller setup
      _checkAndSetupController();
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _actionIconAnimationController.dispose();
    _oldController?.removeListener(_onControllerUpdate);
    _oldController?.removeListener(_onControllerInitListener);
    _oldController = null;
    _outroController?.dispose();
    _narrationPlayer.dispose();
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

    // Only check for a loop restart while actually playing and not
    // already mid-outro — avoids false triggers from seeking/scrubbing.
    if (isPlaying && !_showingOutro) {
      _checkForLoopRestart(controller);
    }

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
  }

  void _handleSingleTapToggle() {
    if (_showingOutro) return; // ignore taps while the outro is playing
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

          // Branded outro overlay — fully covers the creator's (paused)
          // video while the 4-second clip + narration play.
          if (_showingOutro && _outroController != null && _outroController!.value.isInitialized)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _outroController!.value.aspectRatio,
                    child: VideoPlayer(_outroController!),
                  ),
                ),
              ),
            ),

          // Scale and Fade Animation Play/Pause Overlay Engine
          if (_showPlayIconOverlay && !_showingOutro)
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
          if (_isBuffering && _isControllerInitialized && !_showingOutro)
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

          // Persistent tagline + creator caption — hidden during the
          // outro so it doesn't overlap the branded clip.
          if (!_showingOutro)
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
