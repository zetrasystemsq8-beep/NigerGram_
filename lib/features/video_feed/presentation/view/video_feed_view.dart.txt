// lib/features/video_feed/presentation/view/video_feed_view.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_state.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_item.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> feedDomains = [
  'All', 'Software', 'AI/ML', 'Business', 'Engineering', 'Design', 'Research',
];

class VideoFeedView extends StatefulWidget {
  const VideoFeedView({super.key, this.isActive = true});

  final bool isActive;

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

  final Map<int, bool> _initializationStatus = {};

  String _selectedDomain = 'All';

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

  @override
  void didUpdateWidget(covariant VideoFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (!widget.isActive) {
        debugPrint('🟡 VideoFeedView became INACTIVE — pausing focused controller');
        _controllers[_focusedIndex]?.pause();
      } else {
        debugPrint('🟢 VideoFeedView became ACTIVE — resuming focused controller');
        _controllers[_focusedIndex]?.play();
      }
    }
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

  /// Called whenever the domain filter changes — resets playback state
  /// since the underlying video list (and therefore indices) changes.
  void _onDomainChanged(String domain) {
    if (domain == _selectedDomain) return;
    _clearAndDisposeAllControllers();
    setState(() {
      _selectedDomain = domain;
      _focusedIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    context.read<VideoFeedCubit>().onPageChanged(0);
  }

  List<VideoEntity> _filteredVideos(List<VideoEntity> all) {
    if (_selectedDomain == 'All') return all;
    return all.where((v) => v.category == _selectedDomain).toList();
  }

  void _onPageChanged(int index, List<VideoEntity> videos) {
    if (!mounted) return;

    debugPrint('➡️ Page changed to index $index for videoId=${videos[index].id}');

    setState(() {
      _focusedIndex = index;
    });

    context.read<VideoFeedCubit>().onPageChanged(index);

    _manageControllerLifecycle(index, videos);
  }

  void _manageControllerLifecycle(int index, List<VideoEntity> videos) {
    if (widget.isActive) {
      _getOrCreateController(index, videos)?.play();
    } else {
      _getOrCreateController(index, videos)?.pause();
    }

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
    } catch (err) {
      debugPrint('Prefetch failed for $url: $err');
    }
  }

  VideoPlayerController? _getOrCreateController(int index, List<VideoEntity> videos) {
    if (index < 0 || index >= videos.length) return null;

    if (_controllers.containsKey(index)) {
      return _controllers[index];
    }

    _initializationStatus[index] = false;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videos[index].videoUrl),
    );

    _controllers[index] = controller;

    controller.initialize().then((_) {
      if (!mounted) return;
      if (_controllers[index] != controller) return;

      debugPrint('✅ Video initialized for index $index: ${videos[index].id}');

      controller.setLooping(true);
      _initializationStatus[index] = true;

      if (index == _focusedIndex && widget.isActive) {
        controller.play();
      } else {
        controller.pause();
      }

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
              // Note: the end-of-video audio + branded overlay are now
              // triggered inside VideoFeedViewOptimizedVideoPlayer itself
              // (same loop-detection technique), not here — keeping this
              // file focused on view/loop analytics only.

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

  Widget _buildDomainFilterBar() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: feedDomains.length,
        itemBuilder: (context, index) {
          final domain = feedDomains[index];
          final selected = domain == _selectedDomain;
          return GestureDetector(
            onTap: () => _onDomainChanged(domain),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  domain,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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

        final filteredVideos = _filteredVideos(state.videos);

        if (filteredVideos.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F0F11),
            body: Column(
              children: [
                SafeArea(bottom: false, child: _buildDomainFilterBar()),
                Expanded(
                  child: Center(
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
                          _selectedDomain == 'All'
                              ? 'No showcases yet'
                              : 'No $_selectedDomain builds yet',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: context.fontSize(15),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: bottomNavigationPadding),
                child: PageView.builder(
                  key: ValueKey(_selectedDomain),
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (index) => _onPageChanged(index, filteredVideos),
                  itemCount: filteredVideos.length,
                  itemBuilder: (context, index) {
                    final controller = _controllers[index];
                    final isInitialized = _initializationStatus[index] ?? false;

                    if (controller == null) {
                      _getOrCreateController(index, filteredVideos);
                    }

                    final currentController = _controllers[index];

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: VideoFeedViewItem(
                            key: ValueKey('${filteredVideos[index].id}_${isInitialized ? 'init' : 'loading'}'),
                            videoItem: filteredVideos[index],
                            controller: currentController,
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
                        // "What was built" label, sitting just above the
                        // username/description — reframes the caption area
                        // as a build log rather than a generic post caption.
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: context.h(96),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFE2C55).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  filteredVideos[index].category?.isNotEmpty == true
                                      ? filteredVideos[index].category!
                                      : 'Build',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(bottom: false, child: _buildDomainFilterBar()),
            ],
          ),
        );
      },
    );
  }
}
