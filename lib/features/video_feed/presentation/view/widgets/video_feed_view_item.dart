import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/video_feed_view_overlay_section.dart';
import 'package:video_player/video_player.dart';

class VideoFeedViewItem extends StatefulWidget {
  const VideoFeedViewItem({
    required this.videoItem,
    required this.controller,
    super.key,
  });

  final VideoEntity videoItem;
  final VideoPlayerController? controller;

  @override
  State<VideoFeedViewItem> createState() => _VideoFeedViewItemState();
}

class _VideoFeedViewItemState extends State<VideoFeedViewItem> {
  bool _isLiked = false;
  int _likeCount = 0;
  
  /// High-velocity particle overlay array to map simultaneous double-tap coordinate spikes
  final List<_HeartParticle> _heartParticles = [];

  @override
  void initState() {
    super.initState();
    _likeCount = widget.videoItem.likeCount;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoItem.id)
          .collection('likes')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() => _isLiked = doc.exists);
      }
    } catch (e) {
      debugPrint('NigerGram Log: Error checking read authorization metrics: $e');
    }
  }

  /// Institutional-Grade Optimistic Execution Framework
  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoItem.id);
    final likeRef = videoRef.collection('likes').doc(user.uid);

    // Cache current state for emergency rollbacks if network pipeline drops out
    final bool previousLikedState = _isLiked;
    final int previousLikeCount = _likeCount;

    // Instantaneous UI Feedback (Zero network lag or stalling)
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
    });

    try {
      if (previousLikedState) {
        await likeRef.delete();
        await videoRef.update({'likeCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({
          'userId': user.uid, 
          'likedAt': FieldValue.serverTimestamp(),
        });
        await videoRef.update({'likeCount': FieldValue.increment(1)});
      }
    } catch (error) {
      debugPrint('NigerGram Log: Network write failed. Initiating state rollback protection. $error');
      // Rollback to secure data synchronization bounds
      if (mounted) {
        setState(() {
          _isLiked = previousLikedState;
          _likeCount = previousLikeCount;
        });
      }
    }
  }

  /// Captures coordinates on double-tap to deploy a dynamic floating heart visual particle
  void _handleDoubleTapCanvas(TapDownDetails details) {
    if (!_isLiked) {
      _toggleLike();
    }
    
    final int dynamicParticleId = DateTime.now().microsecondsSinceEpoch;
    final Offset tapLocation = details.localPosition;

    setState(() {
      _heartParticles.add(_HeartParticle(id: dynamicParticleId, position: tapLocation));
    });

    // Automatically purge particle assets from memory structure post-animation lifecycle loop
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _heartParticles.removeWhere((particle) => particle.id == dynamicParticleId);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full Canvas Primary Gesture Capture Matrix
        GestureDetector(
          onTapDown: (details) {
            // Internal hooks can capture single tap play/pause controls cleanly here
          },
          onDoubleTapDown: _handleDoubleTapCanvas,
          onDoubleTap: () {}, // Handled explicitly via high-fidelity positional coordinates above
          behavior: HitTestBehavior.opaque,
          child: VideoFeedViewOptimizedVideoPlayer(
            controller: widget.controller,
            videoId: widget.videoItem.id,
          ),
        ),

        // Double-Tap Immersive Heart Burst Canvas Layer
        ..._heartParticles.map((particle) {
          return _FloatingHeartOverlay(
            key: ValueKey(particle.id),
            position: particle.position,
          );
        }),

        // Interactive Presentation Overlay Layer
        VideoFeedViewOverlaySection(
          profileImageUrl: widget.videoItem.profileImageUrl,
          username: widget.videoItem.username,
          description: widget.videoItem.description,
          isBookmarked: false,
          isLiked: _isLiked,
          likeCount: _likeCount,
          commentCount: widget.videoItem.commentCount,
          shareCount: widget.videoItem.shareCount,
          onLikeTapped: _toggleLike,
        ),
      ],
    );
  }
}

/// Helper model parsing schema for real-time item tracking
class _HeartParticle {
  _HeartParticle({required this.id, required this.position});
  final int id;
  final Offset position;
}

/// High-Fidelity Animated Heart Element that scales and floats upward cleanly
class _FloatingHeartOverlay extends StatefulWidget {
  const _FloatingHeartOverlay({required this.position, super.key});
  final Offset position;

  @override
  State<_FloatingHeartOverlay> createState() => _FloatingHeartOverlayState();
}

class _FloatingHeartOverlayState extends State<_FloatingHeartOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.4).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 60),
    ]).animate(_animationController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    ]).animate(_animationController);

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Centers the drawing origin completely above the user's touch vector radius
    const double heartDimensions = 100.0;
    final double adjustedLeft = widget.position.dx - (heartDimensions / 2);
    final double adjustedTop = widget.position.dy - (heartDimensions / 2);

    return Positioned(
      left: adjustedLeft,
      top: adjustedTop,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Subtle upward drift modification applied smoothly over runtime lifecycle
          final double upwardDriftModifier = _animationController.value * -35.0;

          return Transform.translate(
            offset: Offset(0, upwardDriftModifier),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFFE2C55), // High-intensity corporate brand neon pink hue
                  size: heartDimensions,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 15,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
