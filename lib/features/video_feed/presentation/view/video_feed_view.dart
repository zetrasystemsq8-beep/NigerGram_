import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nigergram/core/utils/extensions/context_size_extensions.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_cubit.dart';
import 'package:nigergram/features/video_feed/presentation/bloc/video_feed_state.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_item.dart';
import 'package:video_player/video_player.dart';

class VideoFeedView extends StatefulWidget {
  const VideoFeedView({super.key});

  @override
  State<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends State<VideoFeedView> {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _controllers = {};
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers.values) {
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
