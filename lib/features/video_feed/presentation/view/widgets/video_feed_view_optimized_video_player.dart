import 'package:flutter/material.dart';
import 'package:nigergram/core/design_system/colors.dart';
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

class _VideoFeedViewOptimizedVideoPlayerState extends State<VideoFeedViewOptimizedVideoPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _loadingController;
  bool _isBuffering = false;
  VideoPlayerController? _oldController;
  String? _currentVideoId;
  bool _isPlaying = false;
  Key _playerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _oldController = widget.controller;
    _currentVideoId = widget.videoId;
    _addControllerListener();
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    // Handle Uninitialized or Null Controller Textures gracefully
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: RotationTransition(
          turns: Tween<double>(begin: 0, end: 1).animate(_loadingController),
          child: const CircularProgressIndicator(
            color: white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Stack(
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

        // 2. Isolated Screen-Space Buffering Overlay
        // Positioned outside FittedBox to prevent any geometric stretching or warping on varying device displays
        if (_isBuffering)
          const Center(
            child: CircularProgressIndicator(
              color: white,
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }
}
