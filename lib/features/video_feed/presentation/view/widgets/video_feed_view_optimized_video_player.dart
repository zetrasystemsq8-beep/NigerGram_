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
  // ⚠️ This string must match pubspec.yaml's assets entry EXACTLY,
  // character for character — a mismatch here fails silently.
  // Confirm this matches your real uploaded filename before relying on it.
  static const String _outroVideoAsset = 'assets/sounds/lv_7328538278142004487_20260818020652.mp4';
  static const String _narrationAsset = 'sounds/zetra_spoken.wav';

  VideoPlayerController? _outroController;
  final AudioPlayer _narrationPlayer = AudioPlayer();
  bool _showingOutro = false;
  bool _outroControllerReady = false;

  // Fires once per play-through when the main video reaches its end —
  // replaces the old "wait for a loop-restart jump" detection, since
  // setLooping(false) means no restart ever happens on its own.
  bool _endTriggeredForThisPlay = false;
  static const _endProximity = Duration(milliseconds: 250);

  Future<void> _ensureOutroControllerReady() async {
    if (_outroControllerReady) return;
    final outro = VideoPlayerController.asset(_outroVideoAsset);
    try {
      await outro.initialize();
      await outro.setLooping(false);
      await outro.setVolume(0);
      _outroController = outro;
      _outroControllerReady = true;
    } catch (_) {
      _outroControllerReady = false;
    }
  }

  Future<void> _playOutroThenResume(VideoPlayerController mainController) async {
    if (_showingOutro) return;

    mainController.pause();

    await _ensureOutroControllerReady();
    final outro = _outroController;

    if (!mounted) return;

    if (outro == null || !_outroControllerReady) {
      // Outro clip unavailable — play narration alone, briefly, then pause.
      // _showingOutro still flips true here so the main video widget is
      // removed from the tree for this fallback path too (nothing to
      // decode, but keeps behavior/visuals consistent either way).
      setState(() => _showingOutro = true);
      try {
        await _narrationPlayer.stop();
        await _narrationPlayer.play(AssetSource(_narrationAsset));
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
      _finishOutroAndPause(mainController);
      return;
    }

    // Setting _showingOutro = true here removes the creator's
    // VideoPlayer widget from the tree on the very next build, before
    // the outro's own VideoPlayer widget gets added — so there's never
    // a frame where both are mounted simultaneously. Many Android
    // devices only support a small number of simultaneously active
    // hardware video decoders; leaving the creator's video Texture
    // mounted (even paused) while the outro tries to decode competes
    // for those same decoder slots, which was why the outro froze on
    // its first frame while its audio/timing kept working fine.
    setState(() => _showingOutro = true);

    await outro.seekTo(Duration.zero);
    await outro.play();

    try {
      await _narrationPlayer.stop();
      await _narrationPlayer.play(AssetSource(_narrationAsset));
    } catch (_) {}

    void onOutroTick() {
      if (!mounted) return;
      final value = outro.value;
      if (!value.isInitialized) return;
      final duration = value.duration;
      if (duration.inMilliseconds > 0 &&
          value.position >= duration - const Duration(milliseconds: 150)) {
        outro.removeListener(onOutroTick);
        _finishOutroAndPause(mainController);
      }
    }

    outro.addListener(onOutroTick);
  }

  /// Outro (and narration) finished — everything stops here. The
  /// creator's video does NOT auto-restart; user has to tap play again
  /// if they want to rewatch, matching "if it finishes everything should
  /// pause."
  void _finishOutroAndPause(VideoPlayerController mainController) {
    if (!mounted) return;
    setState(() => _showingOutro = false);
    mainController.pause();
    mainController.seekTo(Duration.zero);
    _endTriggeredForThisPlay = false;
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

    _checkAndSetupController();
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

    // Check for end-of-video on every tick, playing or not — catches the
    // case where the platform already auto-paused right at the end
    // before our next "isPlaying" tick would have fired.
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
          // Only mounted when the outro is NOT showing — this widget
          // being fully removed from the tree (not just hidden behind
          // the outro) during playback of the outro is the actual fix
          // for the outro freezing on its first frame. See the note in
          // _playOutroThenResume above for why.
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

          // Branded outro overlay — now the ONLY video decoder active on
          // screen while it plays, since the creator's video widget above
          // is fully removed from the tree during this time.
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

          if (_isBuffering && _isControllerInitialized && !_showingOutro)
            Center(
              child: _NigerGramSpinner(controller: _loadingController, size: context.sq(34)),
            ),

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

          // Tagline + creator caption — now cycles through 8 positions
          // around the perimeter (4 corners + 4 edge-midpoints), not
          // just the corners.
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

/// Cycles its child through 8 positions around the perimeter of
/// whatever space it's given (wrap in Positioned.fill to use the full
/// video area): all 4 corners plus all 4 edge-midpoints, in clockwise
/// order.
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
