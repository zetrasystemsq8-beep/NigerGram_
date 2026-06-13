import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_item.dart';
import 'package:video_player/video_player.dart';

class VideoDetailView extends StatefulWidget {
  final String videoId;

  const VideoDetailView({super.key, required this.videoId});

  @override
  State<VideoDetailView> createState() => _VideoDetailViewState();
}

class _VideoDetailViewState extends State<VideoDetailView> {
  VideoPlayerController? _controller;
  VideoEntity? _videoEntity;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeInstitutionalPayload();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Fetches video metadata and initializes the high-fidelity player
  Future<void> _initializeInstitutionalPayload() async {
    try {
      // 1. Fetch Video Metadata from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .get();

      if (!doc.exists) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      final data = doc.data()!;
      _videoEntity = VideoEntity(
        id: doc.id,
        videoUrl: data['videoUrl'] ?? '',
        thumbnailUrl: data['thumbnailUrl'] ?? '',
        username: data['username'] ?? 'nigergram_user',
        description: data['description'] ?? '',
        profileImageUrl: data['profileImageUrl'] ?? '',
        likeCount: data['likeCount'] ?? 0,
        commentCount: data['commentCount'] ?? 0,
        shareCount: data['shareCount'] ?? 0,
      );

      // 2. Initialize Video Controller with network optimization
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(_videoEntity!.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('NigerGram Detail Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF0050),
          strokeWidth: 3,
        ),
      );
    }

    if (_hasError || _videoEntity == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Video unavailable',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back', style: TextStyle(color: Color(0xFFFF0050))),
            ),
          ],
        ),
      );
    }

    // Reuse the refined VideoFeedViewItem for visual consistency
    return VideoFeedViewItem(
      videoItem: _videoEntity!,
      controller: _controller,
    );
  }
}
