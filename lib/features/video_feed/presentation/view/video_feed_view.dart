import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_state.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_item.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ GLOBAL KEY - exported for dashboard access
final GlobalKey<VideoFeedViewState> videoFeedKey = GlobalKey<VideoFeedViewState>();

class VideoFeedView extends StatefulWidget {
  const VideoFeedView({super.key});

  @override
  VideoFeedViewState createState() => VideoFeedViewState();
}

// ✅ MADE PUBLIC (removed underscore)
class VideoFeedViewState extends State<VideoFeedView> with WidgetsBindingObserver {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, VoidCallback> _activeListeners = {};
  int _focusedIndex = 0;

  final Set<String> _viewReported = {};
  final Map<String, int> _loopCounts = {};
  final Map<int, bool> _initializationStatus = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseAllVideos();
    _clearAndDisposeAllControllers();
    _pageController.dispose();
    super.dispose();
  }

  // ==================== LIFECYCLE ====================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseAllVideos();
    }
  }

  // ✅ PUBLIC METHODS for Dashboard
  void pauseVideo() {
    if (_controllers.containsKey(_focusedIndex)) {
      _controllers[_focusedIndex]?.pause();
    }
  }

  void resumeVideo() {
    if (_controllers.containsKey(_focusedIndex)) {
      _controllers[_focusedIndex]?.play();
    }
  }

  void _pauseAllVideos() {
    _controllers.forEach((_, controller) {
      controller?.pause();
    });
  }

  void _clearAndDisposeAllControllers() {
    for (var index in _controllers.keys) {
      final controller = _controllers[index];
      final listener = _activeListeners[index];
      if (controller != null) {
        if (listener != null) {
          controller.removeListener(listener);
        }
        controller.dispose();
      }
    }
    _controllers.clear();
    _activeListeners.clear();
    _initializationStatus.clear();
  }

  void _onPageChanged(int index, List<VideoEntity> videos) {
    if (!mounted) return;
    setState(() => _focusedIndex = index);
    context.read<VideoFeedCubit>().onPageChanged(index);
    _manageControllerLifecycle(index, videos);
  }

  void _manageControllerLifecycle(int index, List<VideoEntity> videos) {
    _getOrCreateController(index, videos)?.play();
    _getOrCreateController(index - 1, videos)?.pause();
    _getOrCreateController(index + 1, videos)?.pause();

    _controllers.removeWhere((key, controller) {
      if ((key - index).abs() > 1) {
        final listener = _activeListeners[key];
        if (listener != null) {
          controller.removeListener(listener);
          _activeListeners.remove(key);
        }
        controller.dispose();
        _initializationStatus.remove(key);
        return true;
      }
      return false;
    });

    for (int i = 1; i <= 2; i++) {
      final preIndex = index + i;
      if (preIndex >= 0 && preIndex < videos.length) {
        _prefetchVideo(videos[preIndex].videoUrl);
      }
    }
    if (index >= 0 && index < videos.length) {
      _attachViewListener(index, videos[index].id);
    }
  }

  Future<void> _prefetchVideo(String url) async {
    try {
      await DefaultCacheManager().getSingleFile(url);
    } catch (_) {}
  }

  VideoPlayerController? _getOrCreateController(int index, List<VideoEntity> videos) {
    if (index < 0 || index >= videos.length) return null;
    if (_controllers.containsKey(index)) return _controllers[index];

    _initializationStatus[index] = false;
    final controller = VideoPlayerController.networkUrl(Uri.parse(videos[index].videoUrl));
    _controllers[index] = controller;

    controller.initialize().then((_) {
      if (!mounted) return;
      if (_controllers[index] != controller) return;
      controller.setLooping(true);
      _initializationStatus[index] = true;
      if (index == _focusedIndex) controller.play();
      setState(() {});
    }).catchError((error) {
      debugPrint('❌ Video init failed: $error');
      if (mounted) setState(() => _initializationStatus[index] = false);
    });
    return controller;
  }

  void _attachViewListener(int index, String videoId) {
    final controller = _controllers[index];
    if (controller == null) return;
    final oldListener = _activeListeners[index];
    if (oldListener != null) {
      controller.removeListener(oldListener);
      _activeListeners.remove(index);
    }
    Duration lastPosition = Duration.zero;

    void currentListener() {
      if (!mounted) return;
      if (controller.value.isPlaying) {
        final pos = controller.value.position;
        if (pos > lastPosition) lastPosition = pos;
        if (pos.inSeconds >= 3 && !_viewReported.contains(videoId)) {
          _viewReported.add(videoId);
          FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .update({'viewCount': FieldValue.increment(1)})
              .catchError((_) {});
        }
        final duration = controller.value.duration;
        if (duration.inMilliseconds > 0 && pos >= duration - const Duration(milliseconds: 150)) {
          Future.microtask(() async {
            await Future.delayed(const Duration(milliseconds: 300));
            if (!mounted) return;
            if (controller.value.position.inMilliseconds < 500) {
              final current = (_loopCounts[videoId] ?? 0) + 1;
              _loopCounts[videoId] = current;
              FirebaseFirestore.instance
                  .collection('videos')
                  .doc(videoId)
                  .update({'loopCount': FieldValue.increment(1)})
                  .catchError((_) {});
            }
          });
        }
      }
    }

    _activeListeners[index] = currentListener;
    controller.addListener(currentListener);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight;
    return BlocBuilder<VideoFeedCubit, VideoFeedState>(
      builder: (context, state) {
        if (state.isLoading && state.videos.isEmpty) {
          return Scaffold(
            backgroundColor: NGColors.background,
            body: const Center(
              child: CircularProgressIndicator(color: NGColors.accent),
            ),
          );
        }

        if (state.errorMessage.isNotEmpty) {
          return Scaffold(
            backgroundColor: NGColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: NGColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage,
                    style: TextStyle(color: NGColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<VideoFeedCubit>().loadVideos(),
                    style: ElevatedButton.styleFrom(backgroundColor: NGColors.accent),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.videos.isEmpty) {
          return Scaffold(
            backgroundColor: NGColors.background,
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_collection_rounded, color: NGColors.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No videos yet',
                    style: TextStyle(color: NGColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          key: videoFeedKey,
          backgroundColor: NGColors.background,
          body: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) => _onPageChanged(index, state.videos),
              itemCount: state.videos.length,
              itemBuilder: (context, index) {
                final controller = _controllers[index];
                final isInitialized = _initializationStatus[index] ?? false;

                if (controller == null) {
                  _getOrCreateController(index, state.videos);
                  return const Center(
                    child: CircularProgressIndicator(color: NGColors.accent),
                  );
                }

                return VideoFeedViewItem(
                  key: ValueKey('${state.videos[index].id}_${isInitialized ? 'init' : 'loading'}'),
                  videoItem: state.videos[index],
                  controller: controller,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
