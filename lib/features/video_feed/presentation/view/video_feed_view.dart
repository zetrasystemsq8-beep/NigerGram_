import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/core/design_system/colors.dart';
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

class _VideoFeedViewState extends State<VideoFeedView> with WidgetsBindingObserver {
  /// Maximum number of controllers to keep in cache
  final int _maxCacheSize = 3;

  /// The current videos to display
  List<VideoEntity> _videos = [];

  /// Current visible page
  int _currentPage = 0;

  /// PageView controller
  final PreloadPageController _pageController = PreloadPageController();

  /// Whether the app is currently active
  bool _isAppActive = true;

  /// LRU cache of video controllers by video ID
  final Map<String, VideoPlayerController> _controllerCache = {};

  /// Ordered list of video IDs by most recently accessed
  final List<String> _accessOrder = [];

  /// Set of video IDs currently being disposed to prevent race conditions
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
        setState(() {
          _videos = state.videos;
        });
        await _initAndPlayVideo(0);
      }
    });
  }

  Future<void> _cleanupAndReinitializeCurrentVideo() async {
    if (_videos.isEmpty || _currentPage >= _videos.length) return;

    await _pauseAllControllers();

    final videoId = _videos[_currentPage].id;
    final controller = _getController(videoId);

    if (controller != null && (controller.value.hasError || !controller.value.isInitialized)) {
      await _removeController(videoId);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    await _initAndPlayVideo(_currentPage);
  }

  Future<void> _initAndPlayVideo(int index) async {
    if (_videos.isEmpty || index >= _videos.length) return;

    final video = _videos[index];
    await _getOrCreateController(video);
    await _playController(video.id);

    if (mounted) setState(() {});
  }

  VideoPlayerController? _getController(String videoId) {
    return _controllerCache[videoId];
  }

  void _touchController(String videoId) {
    _accessOrder
      ..remove(videoId)
      ..add(videoId);
  }

  Future<VideoPlayerController?> _getOrCreateController(VideoEntity video) async {
    if (_controllerCache.containsKey(video.id)) {
      _touchController(video.id);
      return _controllerCache[video.id];
    }

    try {
      final videoFile = await context.read<VideoFeedCubit>().getCachedVideoFile(video.videoUrl);
      final controller = VideoPlayerController.file(videoFile);

      await controller.initialize();
      await controller.setLooping(true);

      _controllerCache[video.id] = controller;
      _touchController(video.id);
      _enforceCacheLimit();

      return controller;
    } catch (e) {
      debugPrint('Error initializing controller: $e');
      return null;
    }
  }

  Future<void> _playController(String videoId) async {
    final controller = _controllerCache[videoId];
    if (controller != null && controller.value.isInitialized && !controller.value.isPlaying) {
      try {
        await controller.play();
      } catch (e) {
        debugPrint('Error playing video: $e');
      }
    }
  }

  Future<void> _pauseAllControllers() async {
    final controllers = List<VideoPlayerController>.from(_controllerCache.values);
    for (final controller in controllers) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          await controller.pause();
          await controller.seekTo(Duration.zero);
        }
      } catch (e) {
        debugPrint('Error pausing video: $e');
      }
    }
  }

  Future<void> _removeController(String videoId) async {
    if (_disposingControllers.contains(videoId)) return;
    _disposingControllers.add(videoId);

    try {
      final controller = _controllerCache[videoId];
      if (controller != null) {
        _controllerCache.remove(videoId);
        _accessOrder.remove(videoId);
        try {
          if (controller.value.isInitialized) {
            await controller.pause();
          }
          await controller.dispose();
        } catch (e) {
          debugPrint('Error disposing controller: $e');
        }
      }
    } finally {
      _disposingControllers.remove(videoId);
    }
  }

  void _enforceCacheLimit() {
    while (_controllerCache.length > _maxCacheSize && _accessOrder.isNotEmpty) {
      final oldestId = _accessOrder.first;
      _removeController(oldestId);
    }
  }

  Future<void> _disposeAllControllers() async {
    _pageController.dispose();
    final controllerIds = List<String>.from(_controllerCache.keys);
    for (final id in controllerIds) {
      await _removeController(id);
    }
    _controllerCache.clear();
    _accessOrder.clear();
  }

  Future<void> _manageControllerWindow(int currentPage) async {
    if (_videos.isEmpty) return;

    final windowStart = (currentPage - 1).clamp(0, _videos.length - 1);
    final windowEnd = (currentPage + 1).clamp(0, _videos.length - 1);

    final idsToKeep = <String>{};
    for (int i = windowStart; i <= windowEnd; i++) {
      if (i < _videos.length) {
        idsToKeep.add(_videos[i].id);
      }
    }

    final idsToDispose = _controllerCache.keys.where((id) => !idsToKeep.contains(id)).toList();
    for (final id in idsToDispose) {
      await _removeController(id);
    }

    if (currentPage < _videos.length) {
      await _getOrCreateController(_videos[currentPage]);
      if (windowStart < currentPage && windowStart >= 0) {
        await _getOrCreateController(_videos[windowStart]);
      }
      if (windowEnd > currentPage && windowEnd < _videos.length) {
        await _getOrCreateController(_videos[windowEnd]);
      }
    }
  }

  Future<void> _handlePageChange(int newPage) async {
    if (_videos.isEmpty || newPage >= _videos.length) return;

    final previousPage = _currentPage;
    _currentPage = newPage;
    final isFastScroll = (newPage - previousPage).abs() > 1;

    await _pauseAllControllers();

    try {
      if (isFastScroll) {
        final videoId = _videos[newPage].id;
        final idsToDispose = List<String>.from(_controllerCache.keys);
        for (final id in idsToDispose) {
          if (id != videoId) {
            await _removeController(id);
          }
        }
      }

      await _manageControllerWindow(newPage);

      if (_videos.isNotEmpty && newPage < _videos.length) {
        await _initAndPlayVideo(newPage);
      }

      if (mounted) {
        await context.read<VideoFeedCubit>().onPageChanged(newPage);
      }
    } catch (e) {
      debugPrint('Error handling page change: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RepaintBoundary(
        child: BlocListener<VideoFeedCubit, VideoFeedState>(
          listenWhen: (p, c) =>
              p.videos != c.videos || p.isLoading != c.isLoading || p.preloadedVideoUrls != c.preloadedVideoUrls,
          listener: (context, state) {
            setState(() => _videos = state.videos);
            _manageControllerWindow(_currentPage);
          },
          child: _videos.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : PreloadPageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: _pageController,
                  itemCount: _videos.length,
                  preloadPagesCount: 1, // Lookahead prefetching to ensure snappy rendering
                  physics: const AlwaysScrollableScrollPhysics(),
                  onPageChanged: _handlePageChange,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return RepaintBoundary(
                      child: VideoFeedViewItem(
                        key: ValueKey(video.id),
                        controller: _getController(video.id),
                        videoItem: video,
                      ),
                    );
                  },
                ),
          ),
        ),
    );
  }
}
