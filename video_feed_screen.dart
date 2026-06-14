import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/presentation/widgets/video_feed_view_item.dart';

/// Institutional-grade infinite video feed controller container.
/// Manages aggressive memory reclamation and context switching across active nodes.
class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  final List<VideoEntity> _videos = [];
  final Map<int, VideoPlayerController> _controllers = {};
  
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMoreVideos = true;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchVideoBatch();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  /// Explicit layout clean-up to prevent concurrent memory leaks across unmounted views
  void _disposeAllControllers() {
    for (final controller in _controllers.values) {
      controller.pause();
      controller.dispose();
    }
    _controllers.clear();
  }

  /// Dynamic batch execution strategy pulling raw streams directly from the Firestore collection.
  /// Modified to support legacy documents without timestamps to fix the 'spinning' loading error.
  Future<void> _fetchVideoBatch() async {
    if (_isLoading || !_hasMoreVideos) return;

    setState(() => _isLoading = true);

    try {
      // ZETRA FIX: Removed .orderBy('timestamp') to prevent Firestore from ignoring 
      // documents missing the field, which was causing an empty result set and infinite loading.
      Query query = FirebaseFirestore.instance
          .collection('videos')
          .limit(10); 

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreVideos = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = querySnapshot.docs.last;

      final List<VideoEntity> fetchedVideos = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Safety check for null-safety across all dynamic fields
        return VideoEntity(
          id: doc.id,
          videoUrl: data['videoUrl'] ?? '',
          thumbnailUrl: data['thumbnailUrl'] ?? '',
          username: data['username'] ?? 'nigergram_user',
          description: data['description'] ?? '',
          profileImageUrl: data['profileImageUrl'] ?? '',
          likeCount: data['likeCount'] ?? 0,
          commentCount: data['commentCount'] ?? 0,
          shareCount: data['shareCount'] ?? 0,
          timestamp: data['timestamp'] != null 
              ? (data['timestamp'] as Timestamp).toDate() 
              : DateTime.now(), // Fallback for local cache synchronization
        );
      }).where((video) => video.videoUrl.isNotEmpty).toList(); 

      setState(() {
        _videos.addAll(fetchedVideos);
        _isLoading = false;
      });

      // Initialize the first video configuration sequentially if it's the initial batch load
      if (_videos.isNotEmpty && _controllers.isEmpty) {
        _initializeControllerAtIndex(0);
      }
    } catch (e) {
      debugPrint('Zetra Feed Layer critical payload acquisition error: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Low-Data optimization resource manager. Allocates buffer resources dynamically.
  Future<void> _initializeControllerAtIndex(int index) async {
    if (index < 0 || index >= _videos.length) return;
    if (_controllers.containsKey(index)) return;

    final video = _videos[index];
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(video.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    _controllers[index] = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      
      // Safety check to verify index context didn't change mid-initialization
      if (mounted && _focusedIndex == index) {
        setState(() {});
        await controller.play();
      }
    } catch (e) {
      debugPrint('Dynamic asset initialization exception on index [$index]: $e');
    }
  }

  /// Prunes non-adjacent video buffers aggressively to minimize mobile device memory overhead.
  void _onPageChanged(int index) {
    if (index >= _videos.length) return;

    setState(() => _focusedIndex = index);

    // Context trigger to fetch next logical payload window
    if (index >= _videos.length - 2) {
      _fetchVideoBatch();
    }

    // Play target index asset and spin down background threads
    _controllers[index]?.play();

    // Proactive caching strategy: pre-warm the next item down the layout line
    if (index + 1 < _videos.length) {
      _initializeControllerAtIndex(index + 1);
    }

    // Retain neighbors, terminate distant memory references
    final keysToDispose = _controllers.keys.where((key) => (key - index).abs() > 1).toList();
    for (final key in keysToDispose) {
      _controllers[key]?.pause();
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty && _isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF0050),
            strokeWidth: 3,
          ),
        ),
      );
    }

    // Handle empty state if no videos are found in the database
    if (_videos.isEmpty && !_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "No videos found in NigerGram feed.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final video = _videos[index];
          final controller = _controllers[index];

          return VideoFeedViewItem(
            videoItem: video,
            controller: controller,
          );
        },
      ),
    );
  }
}
