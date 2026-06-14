import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final PreloadPageController _pageController = PreloadPageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Connection Error. Please check network.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF0050),
              ),
            );
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No videos available yet.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return PreloadPageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            preloadPagesCount: 3, 
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final Map<String, dynamic> data = 
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              
              final videoItem = {
                'videoUrl': data['videoUrl'] ?? '',
                'thumbnailUrl': data['thumbnailUrl'] ?? '',
                'username': data['username'] ?? 'nigergram_creator',
                'description': data['description'] ?? '',
                'likeCount': data['likeCount'] ?? 0,
                'commentCount': data['commentCount'] ?? 0,
                'shareCount': data['shareCount'] ?? 0,
                'locationState': data['locationState'] ?? 'Nigeria',
              };

              return NigergramVideoPlayer(videoData: videoItem);
            },
          );
        },
      ),
    );
  }
}

class NigergramVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> videoData;
  const NigergramVideoPlayer({super.key, required this.videoData});

  @override
  State<NigergramVideoPlayer> createState() => _NigergramVideoPlayerState();
}

class _NigergramVideoPlayerState extends State<NigergramVideoPlayer> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (widget.videoData['videoUrl'].isEmpty) return;

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoData['videoUrl']),
    );

    try {
      await _videoController.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _videoController.setLooping(true);
        _videoController.play();
      }
    } catch (e) {
      debugPrint("Video initialization failed: $e");
    }
  }

  @override
  void dispose() {
    _videoController.pause();
    _videoController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
      } else {
        _videoController.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // LAYER 1: Low-Data Instant Cover Image
          SizedBox.expand(
            child: widget.videoData['thumbnailUrl'].isNotEmpty
                ? Image.network(
                    widget.videoData['thumbnailUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.black87),
                  )
                : Container(color: Colors.black87),
          ),

          // LAYER 2: Video Player
          if (_isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),

          // LAYER 3: Readability Dark Overlay Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // LAYER 4: Playback Status Icon
          if (_isInitialized && !_videoController.value.isPlaying)
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.black45,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white.withOpacity(0.8), size: 40),
            ),

          // LAYER 5: Localized Trending Location Indicator
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.flame, color: Colors.amber, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Trending',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // LAYER 6: Updated UI Signs (Right-Side Interaction Panel)
          Positioned(
            right: 14,
            bottom: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInteractionItem(
                  iconData: Icons.favorite_rounded, 
                  value: widget.videoData['likeCount'].toString(), 
                  activeColor: const Color(0xFFFF0050)
                ),
                const SizedBox(height: 18),
                _buildInteractionItem(
                  iconData: Icons.chat_bubble_rounded, 
                  value: widget.videoData['commentCount'].toString()
                ),
                const SizedBox(height: 18),
                _buildInteractionItem(
                  iconData: LucideIcons.rocket, // Custom replacement sign for Boost interaction
                  value: widget.videoData['shareCount'].toString()
                ),
                const SizedBox(height: 18),
                _buildInteractionItem(
                  iconData: Icons.bookmark_rounded, 
                  value: ''
                ),
                const SizedBox(height: 22),
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white10,
                  child: Icon(LucideIcons.music, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),

          // LAYER 7: Identity Branding & High-Engagement Connect Layout
          Positioned(
            left: 16,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '@${widget.videoData['username']}',
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        letterSpacing: 0.3
                      ),
                    ),
                    const SizedBox(width: 12),
                    // High-Conversion Pill-Shaped Connection Point
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0050),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0050).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        ),
                        child: const Text(
                          '+ Connect',
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 12, 
                            fontWeight: FontWeight.w800
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: screenSize.width * 0.72,
                  child: Text(
                    widget.videoData['description'],
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 14,
                      height: 1.3
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(LucideIcons.music, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: screenSize.width * 0.5,
                      child: const Text(
                        'Original Sound • Zetra Lab Studio',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionItem({
    required IconData iconData, 
    required String value, 
    Color activeColor = Colors.white
  }) {
    return Column(
      children: [
        Icon(iconData, color: activeColor, size: 32),
        const SizedBox(height: 5),
        if (value.isNotEmpty)
          Text(
            value,
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 12, 
              fontWeight: FontWeight.w600
            ),
          ),
      ],
    );
  }
}
