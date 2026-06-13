import 'package:flutter/material.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
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

  // Placeholder feed items list to compile clean; link this to your bloc/state stream.
  final List<VideoEntity> _videoItems = [];

  @override
  void AlignmentInit() {
    _pageController = PageController();
  }

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

  void _onPageChanged(int index) {
    setState(() {
      _focusedIndex = index;
    });
    _manageControllerLifecycle(index);
  }

  /// Optimizes data consumption and hardware memory by keeping only 
  /// active and immediately adjacent video players initialized.
  void _manageControllerLifecycle(int index) {
    // Play current focused item
    _getOrCreateController(index)?.play();

    // Pause adjacent buffers
    _getOrCreateController(index - 1)?.pause();
    _getOrCreateController(index + 1)?.pause();

    // Aggressively dispose distant players to save cellular data and RAM
    _controllers.removeWhere((key, controller) {
      if ((key - index).abs() > 1) {
        controller.dispose();
        return true;
      }
      return false;
    });
  }

  VideoPlayerController? _getOrCreateController(int index) {
    if (index < 0 || index >= _videoItems.length) return null;
    if (_controllers.containsKey(index)) return _controllers[index];

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_videoItems[index].videoUrl),
    );
    
    _controllers[index] = controller;
    
    controller.initialize().then((_) {
      if (mounted && index == _focusedIndex) {
        controller.setLooping(true);
        controller.play();
        setState(() {});
      }
    });

    return controller;
  }

  @override
  Widget build(BuildContext context) {
    if (_videoItems.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: _videoItems.length,
        itemBuilder: (context, index) {
          final controller = _getOrCreateController(index);
          return VideoFeedViewItem(
            videoItem: _videoItems[index],
            controller: controller,
          );
        },
      ),
    );
  }
}

class VideoFeedViewItem extends StatelessWidget {
  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  const VideoFeedViewItem({
    super.key,
    required this.videoItem,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isInitialized = controller != null && controller!.value.isInitialized;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: isInitialized
                ? Center(
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: VideoPlayer(controller!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white24,
                      strokeWidth: 2,
                    ),
                  ),
          ),
        ),
        const Positioned.fill(
          child: DecorateBackgroundGradient(),
        ),
        Positioned(
          bottom: 100,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProfileIcon(videoItem.profileImageUrl),
              const SizedBox(height: 20),
              _buildInteractionButton(Icons.favorite_rounded, videoItem.likeCount.toString(), color: const Color(0xFFFF0050)),
              const SizedBox(height: 16),
              _buildInteractionButton(Icons.comment_rounded, videoItem.commentCount.toString()),
              const SizedBox(height: 16),
              _buildInteractionButton(Icons.share_rounded, videoItem.shareCount.toString()),
            ],
          ),
        ),
        Positioned(
          bottom: 32,
          left: 16,
          right: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${videoItem.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                videoItem.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileIcon(String url) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[900],
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: url.isEmpty ? const Icon(Icons.person_rounded, color: Colors.white54) : null,
          ),
        ),
        Positioned(
          bottom: -6,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFF0050),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionButton(IconData icon, String countingLabel, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 4),
        Text(
          countingLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class DecorateBackgroundGradient extends StatelessWidget {
  const DecorateBackgroundGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black54,
              Colors.transparent,
              Colors.transparent,
              Colors.black54,
              Colors.black87,
            ],
            stops: [0.0, 0.2, 0.6, 0.85, 1.0],
          ),
        ),
      ),
    );
  }
}
