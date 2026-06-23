// lib/features/video_feed/presentation/view/video_feed_view.dart
import 'dart:async';
import 'dart:ui';

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
  final Map<int, VoidCallback> _activeListeners = {};
  int _focusedIndex = 0;

  /// Track reported view increments so we only increment once per session per video
  final Set<String> _viewReported = {};

  /// Track loop counts per video in-session to report loopCount increments
  final Map<String, int> _loopCounts = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    debugPrint('🟢 VideoFeedView initialized');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _clearAndDisposeAllControllers();
    super.dispose();
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
  }

  void _onPageChanged(int index, List<VideoEntity> videos) {
    if (!mounted) return;

    debugPrint('➡️ Page changed to index $index for videoId=${videos[index].id}');

    setState(() {
      _focusedIndex = index;
    });

    // Notify Cubit of page change for state tracking and pagination
    context.read<VideoFeedCubit>().onPageChanged(index);

    _manageControllerLifecycle(index, videos);
  }

  void _manageControllerLifecycle(int index, List<VideoEntity> videos) {
    // Play current focused item
    _getOrCreateController(index, videos)?.play();

    // Pause adjacent buffers
    _getOrCreateController(index - 1, videos)?.pause();
    _getOrCreateController(index + 1, videos)?.pause();

    // Aggressively dispose distant players to save cellular data and RAM
    _controllers.removeWhere((key, controller) {
      if ((key - index).abs() > 1) {
        final listener = _activeListeners[key];
        if (listener != null) {
          controller.removeListener(listener);
          _activeListeners.remove(key);
        }
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

    // Remove old listener on this slot if it exists before assigning a new one
    final oldListener = _activeListeners[index];
    if (oldListener != null) {
      controller.removeListener(oldListener);
      _activeListeners.remove(index);
    }

    debugPrint('🔔 Attaching clean view listener for videoId=$videoId at index $index');

    Duration lastPosition = Duration.zero;

    void currentListener() {
      if (!mounted) return;
      if (controller.value.isPlaying) {
        final pos = controller.value.position;
        if (pos > lastPosition) {
          lastPosition = pos;
        }

        if (pos.inSeconds >= 3 && !_viewReported.contains(videoId)) {
          _viewReported.add(videoId);
          debugPrint('👁️ Reporting view for $videoId');
          FirebaseFirestore.instance
              .collection('videos')
              .doc(videoId)
              .update({'viewCount': FieldValue.increment(1)}).catchError((e) {
            debugPrint('Failed to increment viewCount for $videoId: $e');
          });
        }

        final duration = controller.value.duration;
        if (duration.inMilliseconds > 0 && pos >= duration - const Duration(milliseconds: 150)) {
          Future.microtask(() async {
            await Future.delayed(const Duration(milliseconds: 300));
            if (!mounted) return;
            final nowPos = controller.value.position;
            if (nowPos.inMilliseconds < 500) {
              final current = (_loopCounts[videoId] ?? 0) + 1;
              _loopCounts[videoId] = current;
              debugPrint('🔁 Loop detected for $videoId — count: $current');
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

    _activeListeners[index] = currentListener;
    controller.addListener(currentListener);
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavigationPadding = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight;

    return BlocBuilder<VideoFeedCubit, VideoFeedState>(
      builder: (context, state) {
        if (state.isLoading && state.videos.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F0F11),
            body: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: const Color(0xFF16161A)),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFFE2C55),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: context.h(20)),
                      Text(
                        'Assembling your personalized feed...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: context.fontSize(14),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (!state.isSuccess && state.errorMessage.isNotEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F0F11),
            body: Center(
              child: Padding(
                padding: context.paddingHorizontal(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: context.paddingAll(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.redAccent,
                        size: context.sq(44),
                      ),
                    ),
                    SizedBox(height: context.h(20)),
                    Text(
                      'Connection interrupted',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.fontSize(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.h(8)),
                    Text(
                      state.errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: context.fontSize(13),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: context.h(28)),
                    GestureDetector(
                      onTap: () => context.read<VideoFeedCubit>().loadVideos(),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: context.paddingVertical(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFE2C55),
                          borderRadius: context.radiusAll(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFE2C55).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Text(
                          'Refresh Feed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: context.fontSize(15),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state.videos.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F0F11),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_collection_rounded,
                    color: Colors.white24,
                    size: context.sq(64),
                  ),
                  SizedBox(height: context.h(16)),
                  Text(
                    'No videos uploaded yet',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: context.fontSize(15),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: EdgeInsets.only(bottom: bottomNavigationPadding),
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) => _onPageChanged(index, state.videos),
              itemCount: state.videos.length,
              itemBuilder: (context, index) {
                final controller = _getOrCreateController(index, state.videos);
                
                return Stack(
                  children: [
                    Positioned.fill(
                      child: VideoFeedViewItem(
                        key: ValueKey(state.videos[index].id),
                        videoItem: state.videos[index],
                        controller: controller,
                      ),
                    ),
                    
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: context.h(180),
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.15),
                                Colors.black.withOpacity(0.50),
                                Colors.black.withOpacity(0.85),
                              ],
                              stops: const [0.0, 0.3, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
