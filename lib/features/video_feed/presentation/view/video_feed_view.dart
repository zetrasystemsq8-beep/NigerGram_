import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_state.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_item.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:video_player/video_player.dart';

class VideoFeedView extends StatefulWidget {
  const VideoFeedView({super.key});

  @override
  State<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends State<VideoFeedView>
    with WidgetsBindingObserver {
  final int _maxCacheSize = 3;
  List<VideoEntity> _videos = [];
  int _currentPage = 0;
  final PreloadPageController _pageController = PreloadPageController();
  bool _isAppActive = true;

  final Map<String, VideoPlayerController> _controllerCache = {};
  final List<String> _accessOrder = [];
  final Set<String> _disposingControllers = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFirstVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeAllControllers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasActive = _isAppActive;
    _isAppActive = state == AppLifecycleState.resumed;
    if (_isAppActive && !wasActive) {
      _cleanupAndReinitializeCurrentVideo();
    } else if (!_isAppActive && wasActive) {
      _pauseAllControllers();
    }
  }

  void _initializeFirstVideo() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<VideoFeedCubit>().state;
      if (state.videos.isNotEmpty) {
        setState(() => _videos = state.videos);
        await _initAndPlayVideo(0);
        _scheduleNextVideoPreload(1);
      }
    });
  }

  Future<void> _cleanupAndReinitializeCurrentVideo() async {
    if (_videos.isEmpty || _currentPage >= _videos.length) return;
    await _pauseAllControllers();
    await _initAndPlayVideo(_currentPage);
  }

  Future<void> _initAndPlayVideo(int index) async {
    if (_videos.isEmpty || index >= _videos.length) return;
    final video = _videos[index];
    await _getOrCreateController(video);
    await _playController(video.id);
    if (mounted) setState(() {});
  }

  VideoPlayerController? _getController(String videoId) =>
      _controllerCache[videoId];

  void _touchController(String videoId) {
    _accessOrder
      ..remove(videoId)
      ..add(videoId);
  }

  Future<VideoPlayerController?> _getOrCreateController(
      VideoEntity video) async {
    if (_controllerCache.containsKey(video.id)) {
      _touchController(video.id);
      return _controllerCache[video.id];
    }

    try {
      final videoFile = await context
          .read<VideoFeedCubit>()
          .getCachedVideoFile(video.videoUrl);
      final controller = VideoPlayerController.file(videoFile);

      await controller.initialize();
      await controller.setLooping(true);

      _controllerCache[video.id] = controller;
      _touchController(video.id);
      _enforceCacheLimit();

      return controller;
    } catch (e) {
      debugPrint('Error loading video: $e');
      return null;
    }
  }

  Future<void> _playController(String videoId) async {
    final controller = _controllerCache[videoId];
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.isPlaying) {
      await controller.play();
    }
  }

  Future<void> _pauseAllControllers() async {
    for (final controller in _controllerCache.values) {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        await controller.pause();
      }
    }
  }

  Future<void> _removeController(String videoId) async {
    if (_disposingControllers.contains(videoId)) return;
    _disposingControllers.add(videoId);
    try {
      final controller = _controllerCache.remove(videoId);
      _accessOrder.remove(videoId);
      if (controller != null) {
        await controller.pause();
        await controller.dispose();
      }
    } finally {
      _disposingControllers.remove(videoId);
    }
  }

  void _enforceCacheLimit() {
    while (_controllerCache.length > _maxCacheSize &&
        _accessOrder.isNotEmpty) {
      _removeController(_accessOrder.first);
    }
  }

  Future<void> _disposeAllControllers() async {
    _pageController.dispose();
    final ids = List<String>.from(_controllerCache.keys);
    for (final id in ids) {
      await _removeController(id);
    }
  }

  Future<void> _handlePageChange(int newPage) async {
    if (_videos.isEmpty || newPage >= _videos.length) return;
    _currentPage = newPage;
    await _pauseAllControllers();

    final windowStart = (newPage - 1).clamp(0, _videos.length - 1);
    final windowEnd = (newPage + 1).clamp(0, _videos.length - 1);
    final idsToKeep = _videos
        .getRange(windowStart, windowEnd + 1)
        .map((v) => v.id)
        .toSet();

    final toRemove =
        _controllerCache.keys.where((id) => !idsToKeep.contains(id)).toList();
    for (final id in toRemove) {
      await _removeController(id);
    }

    await _initAndPlayVideo(newPage);
    await context.read<VideoFeedCubit>().onPageChanged(newPage);

    // Smart Low-Data Optimization: Wait to see if user stays on this video before downloading the next
    _scheduleNextVideoPreload(newPage + 1);
  }

  /// Delays next video preloading to verify intentional consumption patterns
  void _scheduleNextVideoPreload(int nextIndex) {
    if (nextIndex >= _videos.length) return;
    
    Future.delayed(const Duration(milliseconds: 500), () async {
      // If the user has already swiped to a different video within 500ms, abort the preload
      if (!mounted || _currentPage != nextIndex - 1) return;
      
      final nextVideo = _videos[nextIndex];
      await _getOrCreateController(nextVideo);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          BlocListener<VideoFeedCubit, VideoFeedState>(
            listener: (context, state) {
              setState(() => _videos = state.videos);
            },
            child: _videos.isEmpty
                ? _buildLoader()
                : PreloadPageView.builder(
                    scrollDirection: Axis.vertical,
                    controller: _pageController,
                    itemCount: _videos.length,
                    preloadPagesCount: 1,
                    onPageChanged: _handlePageChange,
                    itemBuilder: (context, index) {
                      final video = _videos[index];
                      return VideoFeedViewItem(
                        key: ValueKey(video.id),
                        controller: _getController(video.id),
                        videoItem: video,
                      );
                    },
                  ),
          ),
          _buildTopNavigationOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopNavigationOverlay() {
    return Positioned(
      top: context.h(44),
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.w(16)),
        child: Row(
          children: [
            const Spacer(),
            _buildNavTab("Following", false),
            _buildNavTab("For You", true),
            const Spacer(),
            Icon(Icons.search, color: white, size: context.sq(28)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab(String label, bool isActive) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.w(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? white : white.withAlpha(160),
              fontSize: context.fontSize(17),
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: context.w(24),
              color: white,
            ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: white, strokeWidth: 2),
          SizedBox(height: context.h(16)),
          Text(
            'Loading videos...',
            style: TextStyle(
                color: white.withAlpha(120),
                fontSize: context.fontSize(14)),
          ),
        ],
      ),
    );
  }
}
