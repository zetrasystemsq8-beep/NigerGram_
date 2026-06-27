// lib/features/video_feed/presentation/view/video_feed_view.dart
import 'dart:async';
import 'dart:ui';

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

  /// Track initialization status per index
  final Map<int, bool> _initializationStatus = {};

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
    _initializationStatus.clear();
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
        _initializationStatus.remove(key);
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
    
    // Return existing controller if we have one
    if (_controllers.containsKey(index)) {
      return _controllers[index];
    }

    // Mark as initializing
    _initializationStatus[index] = false;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videos[index].videoUrl),
    );

    _controllers[index] = controller;

    // Proper initialization with state updates
    controller.initialize().then((_) {
      if (!mounted) return;
      
      // Only proceed if this controller is still the one for this index
      if (_controllers[index] != controller) return;
      
      debugPrint('✅ Video initialized for index $index: ${videos[index].id}');
      
      controller.setLooping(true);
      _initializationStatus[index] = true;
      
      // If this is the focused index, play automatically
      if (index == _focusedIndex) {
        controller.play();
      }
      
      // Force rebuild to update UI
      setState(() {});
      
    }).catchError((error) {
      debugPrint('❌ Video initialization failed for index $index: $error');
      if (mounted) {
        _initializationStatus[index] = false;
        setState(() {});
      }
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
            backgroundColor: NGColors.background,
            body: _buildSkeletonLoading(context),
          );
        }

        if (!state.isSuccess && state.errorMessage.isNotEmpty) {
          return Scaffold(
            backgroundColor: NGColors.background,
            body: _buildErrorState(context, state.errorMessage),
          );
        }

        if (state.videos.isEmpty) {
          return Scaffold(
            backgroundColor: NGColors.background,
            body: _buildEmptyState(context),
          );
        }

        return Scaffold(
          backgroundColor: NGColors.background,
          body: Padding(
            padding: EdgeInsets.only(bottom: bottomNavigationPadding),
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
                }
                
                final currentController = _controllers[index];
                
                return VideoFeedViewItem(
                  key: ValueKey('${state.videos[index].id}_${isInitialized ? 'init' : 'loading'}'),
                  videoItem: state.videos[index],
                  controller: currentController,
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 🎨 SKELETON LOADING UI
  Widget _buildSkeletonLoading(BuildContext context) {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          height: MediaQuery.of(context).size.height,
          color: NGColors.surface,
          child: Stack(
            children: [
              // Video placeholder
              Container(
                color: NGColors.surfaceLight,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: NGColors.accent,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 200,
                        height: 12,
                        decoration: BoxDecoration(
                          color: NGColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 10,
                        decoration: BoxDecoration(
                          color: NGColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Skeleton overlay
              Positioned(
                left: 16,
                right: 16,
                top: 48,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: NGColors.divider,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 14,
                            decoration: BoxDecoration(
                              color: NGColors.divider,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 60,
                            height: 10,
                            decoration: BoxDecoration(
                              color: NGColors.divider,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Skeleton bottom
              Positioned(
                bottom: 16,
                left: 16,
                right: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: NGColors.divider,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 150,
                      height: 10,
                      decoration: BoxDecoration(
                        color: NGColors.divider,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ⚠️ ERROR STATE UI
  Widget _buildErrorState(BuildContext context, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NGColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: NGColors.error,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Interrupted',
              style: TextStyle(
                color: NGColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NGColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.read<VideoFeedCubit>().loadVideos(),
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: NGColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: NGColors.accent.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  'Refresh Feed',
                  style: TextStyle(
                    color: NGColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📭 EMPTY STATE UI
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_collection_rounded,
            color: NGColors.textMuted,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No videos yet',
            style: TextStyle(
              color: NGColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to upload!',
            style: TextStyle(
              color: NGColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
