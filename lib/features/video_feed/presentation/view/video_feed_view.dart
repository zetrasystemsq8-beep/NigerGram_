import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_state.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_item.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoFeedView extends StatefulWidget {
  const VideoFeedView({super.key});

  @override
  State<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends State<VideoFeedView> {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _controllers = {};
  int _focusedIndex = 0;

  /// Track reported view increments so we only increment once per session per video
  final Set<String> _viewReported = {};

  /// Track loop counts per video in-session to report loopCount increments
  final Map<String, int> _loopCounts = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.removeListener(() {});
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  void _onPageChanged(int index, List<VideoEntity> videos) {
    if (!mounted) return;

    setState(() {
      _focusedIndex = index;
    });

    // Notify Cubit of page change for state tracking and pagination
    context.read<VideoFeedCubit>().onPageChanged(index);

    _manageControllerLifecycle(index, videos);
  }

  /// ✅ FIXED: Added videos parameter to cleanly initialize controllers during lifecycle changes
  void _manageControllerLifecycle(int index, List<VideoEntity> videos) {
    // Play current focused item
    _getOrCreateController(index, videos)?.play();

    // Pause adjacent buffers
    _getOrCreateController(index - 1, videos)?.pause();
    _getOrCreateController(index + 1, videos)?.pause();

    // Aggressively dispose distant players to save cellular data and RAM
    _controllers.removeWhere((key, controller) {
      if ((key - index).abs() > 1) {
        controller.dispose();
        return true;
      }
      return false;
    });

    // Prefetch next 2 videos to disk cache (no controller instantiation)
    for (int i = 1; i <= 2; i++) {
      final preIndex = index + i;
      if (preIndex >= 0 && preIndex < videos.length) {
        _prefetchVideo(videos[preIndex].videoUrl);
      }
    }

    // Ensure retention/view reporting attached for focused video
    if (index >= 0 && index < videos.length) {
      _attachViewListener(index, videos[index].id);
    }
  }

  Future<void> _prefetchVideo(String url) async {
    try {
      await DefaultCacheManager().getSingleFile(url);
    } catch (err) {
      debugPrint('Prefetch failed for $url: $err');
    }
  }

  VideoPlayerController? _getOrCreateController(int index, List<VideoEntity> videos) {
    if (index < 0 || index >= videos.length) return null;
    if (_controllers.containsKey(index)) return _controllers[index];

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videos[index].videoUrl),
    );

    _controllers[index] = controller;

    controller.initialize().then((_) {
      if (mounted && index == _focusedIndex) {
        controller.setLooping(true);
        controller.play();
        setState(() {});
      }
    }).catchError((error) {
      debugPrint('❌ Video initialization failed for index $index: $error');
    });

    return controller;
  }

  void _attachViewListener(int index, String videoId) {
    final controller = _controllers[index];
    if (controller == null) return;

    // If view already reported for this video in session, skip
    if (_viewReported.contains(videoId)) return;

    // Add listener to watch continuous play position
    Duration lastPosition = Duration.zero;
    var consecutivePlayStart = DateTime.now();

    void listener() {
      if (!mounted) return;
      if (controller.value.isPlaying) {
        final pos = controller.value.position;
        // If playback moved forward, update lastPosition
        if (pos > lastPosition) {
          lastPosition = pos;
        }

        // If we've passed 3 seconds continuously, report view (once)
        if (pos.inSeconds >= 3 && !_viewReported.contains(videoId)) {
          _viewReported.add(videoId);
          FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .update({'viewCount': FieldValue.increment(1)}).catchError((e) {
            debugPrint('Failed to increment viewCount for $videoId: $e');
          });
        }

        // Loop detection: if position is near duration (end), increment loop counter
        final duration = controller.value.duration ?? Duration.zero;
        if (duration.inMilliseconds > 0 && pos >= duration - const Duration(milliseconds: 150)) {
          // small delay to allow loop restart
          Future.microtask(() async {
            // Wait a tick for potential loop restart
            await Future.delayed(const Duration(milliseconds: 300));
            if (!mounted) return;
            final nowPos = controller.value.position;
            if (nowPos.inMilliseconds < 500) {
              // loop restarted
              final current = (_loopCounts[videoId] ?? 0) + 1;
              _loopCounts[videoId] = current;
              FirebaseFirestore.instance
                  .collection('videos')
                  .doc(videoId)
                  .update({'loopCount': FieldValue.increment(1)}).catchError((e) {
                debugPrint('Failed to increment loopCount for $videoId: $e');
              });
            }
          });
        }
      }
    }

    controller.addListener(listener);

    // Ensure we remove the listener when the controller is disposed — reactive cleanup
    // The controller is disposed by existing lifecycle code in _manageControllerLifecycle
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoFeedCubit, VideoFeedState>(
      builder: (context, state) {
        // LOADING STATE: Show spinner when fetching initial videos
        if (state.isLoading && state.videos.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: context.h(16)),
                  Text(
                    'Loading your feed...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.fontSize(14),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // ERROR STATE: Show error message if fetch failed
        if (!state.isSuccess && state.errorMessage.isNotEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: context.sq(56),
                  ),
                  SizedBox(height: context.h(16)),
                  Text(
                    'Failed to load videos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.fontSize(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.h(8)),
                  Text(
                    state.errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: context.fontSize(13),
                    ),
                  ),
                  SizedBox(height: context.h(24)),
                  GestureDetector(
                    onTap: () {
                      context.read<VideoFeedCubit>().loadVideos();
                    },
                    child: Container(
                      padding: context.paddingAll(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE2C55),
                        borderRadius: context.radiusAll(8),
                      ),
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.fontSize(14),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // EMPTY STATE: No videos found
        if (state.videos.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    color: Colors.white30,
                    size: context.sq(64),
                  ),
                  SizedBox(height: context.h(16)),
                  Text(
                    'No videos available',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.fontSize(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // SUCCESS STATE: Render video feed with PageView
        return Scaffold(
          backgroundColor: Colors.black,
          body: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (index) => _onPageChanged(index, state.videos),
            itemCount: state.videos.length,
            itemBuilder: (context, index) {
              final controller = _getOrCreateController(index, state.videos);
              return VideoFeedViewItem(
                videoItem: state.videos[index],
                controller: controller,
              );
            },
          ),
        );
      },
    );
  }
}
