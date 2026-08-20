// lib/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:video_player/video_player.dart';

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
  final String? creatorUsername;

  @override
  State<VideoFeedViewOptimizedVideoPlayer> createState() => _VideoFeedViewOptimizedVideoPlayerState();
}

class _VideoFeedViewOptimizedVideoPlayerState extends State<VideoFeedViewOptimizedVideoPlayer> with TickerProviderStateMixin {
  late AnimationController _loadingController;
  late AnimationController _actionIconAnimationController;
  late AnimationController _outroTransitionController; // NEW: Smooth transition

  bool _isBuffering = false;
  VideoPlayerController? _oldController;
  String? _currentVideoId;
  bool _isPlaying = false;
  Key _playerKey = UniqueKey();

  bool _showPlayIconOverlay = false;
  IconData _overlayIconData = Icons.play_arrow_rounded;

  bool _isControllerInitialized = false;
  bool _isInitializing = false;

  // --- Branded outro shown once a video finishes ---
  static const String _outroVideoAsset = 'assets/sounds/lv_7328538278142004487_20260818020652.mp4';
  static const String _narrationAsset = 'sounds/zetra_spoken.wav';

  VideoPlayerController? _outroController;
  final AudioPlayer _narrationPlayer = AudioPlayer();
  bool _showingOutro = false;
  bool _outroControllerReady = false;
  bool _outroInitializing = false; // NEW: Track outro initialization
  Completer<void>? _outroReadyCompleter; // NEW: Sync initialization

  bool _endTriggeredForThisPlay = false;
  static const _endProximity = Duration(milliseconds: 250);

  /// NEW: Preload outro with better error handling
  Future<void> _ensureOutroControllerReady() async {
    if (_outroControllerReady || _outroInitializing) return;

    _outroInitializing = true;
    _outroReadyCompleter = Completer<void>();

    final outro = VideoPlayerController.asset(_outroVideoAsset);
    try {
      await outro.initialize();
      await outro.setLooping(false);
      await outro.setVolume(0); // Video muted (narration only)

      // NEW: Wait for texture to be ready
      await Future.delayed(const Duration(milliseconds: 100));

      _outroController = outro;
      _outroControllerReady = true;
      _outroInitializing = false;
      _outroReadyCompleter?.complete();

      debugPrint('✅ Outro controller ready');
    } catch (e) {
      debugPrint('❌ Outro init failed: $e');
      _outroControllerReady = false;
      _outroInitializing = false;
      _outroReadyCompleter?.completeError(e);
    }
  }

  /// NEW: Synchronized video + audio playback
  Future<void> _playOutroThenResume(VideoPlayerController mainController) async {
    if (_showingOutro) return;

    mainController.pause();

    // NEW: Ensure outro is ready first
    await _ensureOutroControllerReady();
    final outro = _outroController;

    if (!mounted) return;

    if (outro == null || !_outroControllerReady) {
      // Fallback: narration only
      setState(() => _showingOutro = true);
      try {
        await _narrationPlayer.stop();
        await _narrationPlayer.play(AssetSource(_narrationAsset));
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
      _finishOutroAndPause(mainController);
      return;
    }

    // NEW: Transition animation before showing outro
    setState(() => _showingOutro = true);

    // NEW: Give widget tree time to rebuild (remove main video texture)
    await Future.delayed(const Duration(milliseconds: 150));

    // Sync: Reset and prepare both video and audio
    try {
      await outro.seekTo(Duration.zero);

      // NEW: Start audio AFTER video is seeked
      await _narrationPlayer.stop();

      // NEW: Play both simultaneously with better timing
      await Future.wait([
        outro.play(),
        _narrationPlayer.play(AssetSource(_narrationAsset)),
      ]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => debugPrint('⚠️ Playback timeout'),
      );

      debugPrint('▶️ Outro + narration started (synchronized)');
    } catch (e) {
      debugPrint('❌ Playback error: $e');
    }

    // NEW: Enhanced end detection with buffer
    void onOutroTick() {
      if (!mounted) return;
      final value = outro.value;
      if (!value.isInitialized) return;

      final duration = value.duration;
      final position = value.position;

      if (duration.inMilliseconds > 0 &&
          position >= duration - const Duration(milliseconds: 200)) {
        outro.removeListener(onOutroTick);
        _finishOutroAndPause(mainController);
      }
    }

    outro.addListener(onOutroTick);
  }

  /// NEW: Smooth outro finish with cleanup
  void _finishOutroAndPause(VideoPlayerController mainController) {
    if (!mounted) return;

    // NEW: Fade transition back to main video
    setState(() => _showingOutro = false);

    mainController.pause();
    mainController.seekTo(Duration.zero);
    _endTriggeredForThisPlay = false;

    // NEW: Cleanup
    try {
      _narrationPlayer.stop();
    } catch (_) {}

    debugPrint('⏸️ Outro finished, video paused');
  }

  void _checkForVideoEnd(VideoPlayerController controller) {
    if (_showingOutro || _endTriggeredForThisPlay) return;

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration <= Duration.zero) return;

    if (position >= duration - _endProximity) {
      _endTriggeredForThisPlay = true;
      _playOutroThenResume(controller);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

    _actionIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // NEW: Transition controller for smooth outro entry/exit
    _outroTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _oldController = widget.controller;
    _currentVideoId = widget.videoId;

    _checkAndSetupController();

    // NEW: Preload outro in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureOutroControllerReady();
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

    _showingOutro = false;
    _endTriggeredForThisPlay = false;

    _applyLowDataOptimization(controller);
    _addControllerListener(controller);

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
      _oldController?.removeListener(_onControllerUpdate);
      _oldController?.removeListener(_onControllerInitListener);

      _oldController = widget.controller;
      _currentVideoId = widget.videoId;
      _playerKey = UniqueKey();
      _isBuffering = false;

      _outroController?.pause();
      _narrationPlayer.stop();
      _showingOutro = false;
      _endTriggeredForThisPlay = false;

      _checkAndSetupController();
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _actionIconAnimationController.dispose();
    _outroTransitionController.dispose(); // NEW: Dispose transition controller
    _oldController?.removeListener(_onControllerUpdate);
    _oldController?.removeListener(_onControllerInitListener);
    _oldController = null;
    _outroController?.dispose();
    _narrationPlayer.dispose();
    _outroReadyCompleter = null; // NEW: Clear completer
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

    if (!_showingOutro) {
      _checkForVideoEnd(controller);
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
        }
      });
    }
  }

  void _handleSingleTapToggle() {
    if (_showingOutro) return;
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
          // MAIN VIDEO - Only mounted when outro is NOT showing
          if (!_showingOutro)
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

          // OUTRO VIDEO - Smooth fade in/out
          if (_showingOutro && _outroController != null && _outroController!.value.isInitialized)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showingOutro ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
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
            ),

          // OUTRO LOADING STATE
          if (_showingOutro && _outroInitializing)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: _NigerGramSpinner(controller: _loadingController, size: context.sq(34)),
                ),
              ),
            ),

          // PLAY/PAUSE OVERLAY
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

          // BUFFERING INDICATOR
          if (_isBuffering && _isControllerInitialized && !_showingOutro)
            Center(
              child: _NigerGramSpinner(controller: _loadingController, size: context.sq(34)),
            ),

          // ERROR STATE
          if (controller.value.hasError && !_showingOutro)
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

          // TAGLINE + CREATOR
          if (!_showingOutro)
            Positioned.fill(
              child: IgnorePointer(
                child: _CornerCyclingBadge(
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

/// Cycles through 8 positions with smooth animation
class _CornerCyclingBadge extends StatefulWidget {
  const _CornerCyclingBadge({required this.child});

  final Widget child;

  @override
  State<_CornerCyclingBadge> createState() => _CornerCyclingBadgeState();
}

class _CornerCyclingBadgeState extends State<_CornerCyclingBadge> {
  static const List<Alignment> _positions = [
    Alignment.topLeft,
    Alignment.topCenter,
    Alignment.topRight,
    Alignment.centerRight,
    Alignment.bottomRight,
    Alignment.bottomCenter,
    Alignment.bottomLeft,
    Alignment.centerLeft,
  ];

  int _positionIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _positionIndex = (_positionIndex + 1) % _positions.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: AnimatedAlign(
        alignment: _positions[_positionIndex],
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}

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
          angle: controller.value * 6.28318530718,
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

    const startAngle = -1.5707963268;
    const sweepAngle = 4.18879020479;

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
