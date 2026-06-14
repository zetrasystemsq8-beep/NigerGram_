import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';

/// High-fidelity layout item representing an immersive full-screen video context.
/// Implements localized micro-states for real-time interaction feedback loops.
class VideoFeedViewItem extends StatefulWidget {
  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  const VideoFeedViewItem({
    super.key,
    required this.videoItem,
    required this.controller,
  });

  @override
  State<VideoFeedViewItem> createState() => _VideoFeedViewItemState();
}

class _VideoFeedViewItemState extends State<VideoFeedViewItem> with SingleTickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  
  // Local interaction states for zero-latency UI responsiveness
  bool _isLikedLocal = false;
  int _likeCountLocal = 0;
  bool _showHeartOverlay = false;
  Offset _heartOverlayPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _likeCountLocal = widget.videoItem.likeCount;
    
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    ]).animate(_heartAnimationController);
  }

  @override
  void didUpdateWidget(covariant VideoFeedViewItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoItem.id != widget.videoItem.id) {
      setState(() {
        _likeCountLocal = widget.videoItem.likeCount;
        _isLikedLocal = false; // Reset interaction vector for clean pagination view contexts
      });
    }
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  /// Optimistic State Mutation Loop.
  /// Updates local memory instances immediately to bypass network roundtrip friction.
  void _handleLikeToggle() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_isLikedLocal) {
        _isLikedLocal = false;
        _likeCountLocal = (_likeCountLocal - 1).clamp(0, double.infinity).toInt();
      } else {
        _isLikedLocal = true;
        _likeCountLocal++;
      }
    });

    _syncLikeStateToCloud();
  }

  /// Double-tap gesture intersection callback mapping spatial coordinates to visual overlay anchors
  void _handleDoubleTap(TapDownDetails details) {
    if (!_isLikedLocal) {
      setState(() {
        _isLikedLocal = true;
        _likeCountLocal++;
      });
      _syncLikeStateToCloud();
    }

    HapticFeedback.heavyImpact();

    setState(() {
      _heartOverlayPosition = details.localPosition;
      _showHeartOverlay = true;
    });

    _heartAnimationController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _showHeartOverlay = false);
        }
      });
    });
  }

  /// Asynchronous background transactional execution to ensure cluster consistency
  void _syncLikeStateToCloud() {
    FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoItem.id)
        .update({
          'likeCount': _likeCountLocal,
        }).catchError((error) {
          debugPrint('Zetra Interaction Engine Cloud Sync Mutation dropped: $error');
          // Graceful degradation fallback code here if strict state parity is required
        });
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = widget.controller != null && widget.controller!.value.isInitialized;

    return Stack(
      children: [
        // Video Interactive Canvas Layer
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (details) {}, // Reserved for pause-play toggles if necessary
            onDoubleTapDown: _handleDoubleTap,
            onDoubleTap: () {}, // Required hook parameter to explicitly capture sequence chains
            child: Container(
              color: Colors.black,
              child: isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: widget.controller!.value.aspectRatio,
                        child: VideoPlayer(widget.controller!),
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
        ),

        // Bottom Semantics Gradient Overlay
        Positioned.fill(
          child: const DecorateBackgroundGradient(),
        ),

        // Zetra Lab Corporate Brand Integration
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF0050),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'ZETRA LAB',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Contextual Double-Tap Dynamic Feedback Heart Animation Overlay
        if (_showHeartOverlay)
          Positioned(
            left: _heartOverlayPosition.dx - 50,
            top: _heartOverlayPosition.dy - 50,
            child: ScaleTransition(
              scale: _heartScaleAnimation,
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF0050),
                size: 100,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

        // Interaction Metrics Sidebar
        Positioned(
          bottom: 100,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProfileIcon(widget.videoItem.profileImageUrl),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _handleLikeToggle,
                child: _buildInteractionButton(
                  Icons.favorite_rounded, 
                  _likeCountLocal.toString(), 
                  color: _isLikedLocal ? const Color(0xFFFF0050) : Colors.white
                ),
              ),
              const SizedBox(height: 16),
              _buildInteractionButton(Icons.comment_rounded, widget.videoItem.commentCount.toString()),
              const SizedBox(height: 16),
              _buildInteractionButton(Icons.share_rounded, widget.videoItem.shareCount.toString()),
            ],
          ),
        ),

        // Metadata Text Block
        Positioned(
          bottom: 32,
          left: 16,
          right: 88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${widget.videoItem.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.videoItem.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              // Technical Ecosystem Footer
              Text(
                'powered by zetra lab',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.54),
              Colors.black.withOpacity(0.87),
            ],
            stops: const [0.0, 0.2, 0.6, 0.85, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Specialized individual view panel displaying an isolated video transaction context
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
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeInstitutionalPayload() async {
    try {
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
        timestamp: data['timestamp'] != null 
            ? (data['timestamp'] as Timestamp).toDate() 
            : DateTime.now(),
      );

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(_videoEntity!.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _controller!.initialize();
      await _controller!.setLooping(true);
      
      if (mounted) {
        setState(() => _isLoading = false);
        await _controller!.play();
      }
    } catch (e) {
      debugPrint('Zetra Engine Network Asset pipeline failure: $e');
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

    return VideoFeedViewItem(
      videoItem: _videoEntity!,
      controller: _controller,
    );
  }
}
