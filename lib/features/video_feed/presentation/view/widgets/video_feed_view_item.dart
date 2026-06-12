import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _commentCount = 0;
  
  final List<_HeartParticle> _heartParticles = [];

  @override
  void initState() {
    super.initState();
    _likeCount = widget.videoItem.likeCount;
    _commentCount = widget.videoItem.commentCount;
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

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoItem.id);
    final likeRef = videoRef.collection('likes').doc(user.uid);

    final bool previousLikedState = _isLiked;
    final int previousLikeCount = _likeCount;

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
      debugPrint('NigerGram Log: Network write failed. State rollback deployed. $error');
      if (mounted) {
        setState(() {
          _isLiked = previousLikedState;
          _likeCount = previousLikeCount;
        });
      }
    }
  }

  void _handleSingleTapCanvas() {
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) return;

    HapticFeedback.lightImpact();
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _handleDoubleTapCanvas(TapDownDetails details) {
    if (!_isLiked) {
      _toggleLike();
    }
    
    final int dynamicParticleId = DateTime.now().microsecondsSinceEpoch;
    final Offset tapLocation = details.localPosition;
    final double dynamicTiltAngle = ((dynamicParticleId % 30) - 15) * 3.141592653589793 / 180;

    setState(() {
      _heartParticles.add(_HeartParticle(
        id: dynamicParticleId, 
        position: tapLocation,
        angle: dynamicTiltAngle,
      ));
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _heartParticles.removeWhere((particle) => particle.id == dynamicParticleId);
        });
      }
    });
  }

  /// Displays the interactive glassmorphic comments engine panel
  void _openCommentsSheet() {
    HapticFeedback.mediumImpact();
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag handle bar indicator
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Comments ($_commentCount)',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                
                // Active Live Stream Comments List Engine
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('videos')
                        .doc(widget.videoItem.id)
                        .collection('comments')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050)));
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No comments yet. Start the conversation! 🔥', 
                              style: TextStyle(color: Colors.white38, fontSize: 14)),
                        );
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.white10,
                              backgroundImage: data['profileImageUrl'] != null && data['profileImageUrl'].isNotEmpty
                                  ? NetworkImage(data['profileImageUrl'])
                                  : null,
                              child: data['profileImageUrl'] == null || data['profileImageUrl'].isEmpty
                                  ? const Icon(Icons.person, color: Colors.white54)
                                  : null,
                            ),
                            title: Text(data['username'] ?? 'user', 
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(data['text'] ?? '', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                
                // High-Fidelity Non-stalling Comment Input Dock
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: TextField(
                              controller: commentController,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: 'Add comment for Naija creators...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFFFF0050)),
                          onPressed: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            
                            commentController.clear();
                            HapticFeedback.lightImpact();

                            final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoItem.id);
                            final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                            
                            await videoRef.collection('comments').add({
                              'userId': user.uid,
                              'username': userDoc.data()?['username'] ?? 'naija_user',
                              'profileImageUrl': userDoc.data()?['profilePicUrl'] ?? '',
                              'text': text,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                            
                            await videoRef.update({'commentCount': FieldValue.increment(1)});
                            if (mounted) {
                              setState(() => _commentCount++);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Executes zero-lag content distribution payload share sequences
  void _executeForwardAction() {
    HapticFeedback.vibrate();
    
    // Increment local share counters system metrics
    FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoItem.id)
        .update({'shareCount': FieldValue.increment(1)});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied! Share NigerGram with your friends 🚀'),
        backgroundColor: Color(0xFFFF0050),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: _handleSingleTapCanvas,
          onDoubleTapDown: _handleDoubleTapCanvas,
          onDoubleTap: () {}, 
          behavior: HitTestBehavior.opaque,
          child: IgnorePointer(
            child: VideoFeedViewOptimizedVideoPlayer(
              controller: widget.controller,
              videoId: widget.videoItem.id,
            ),
          ),
        ),

        ..._heartParticles.map((particle) {
          return _FloatingHeartOverlay(
            key: ValueKey(particle.id),
            position: particle.position,
            angle: particle.angle,
          );
        }),

        if (widget.controller != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: widget.controller!,
            builder: (context, value, child) {
              final bool isCurrentlyPaused = !value.isInitialized || !value.isPlaying;
              
              return VideoFeedViewOverlaySection(
                profileImageUrl: widget.videoItem.profileImageUrl,
                username: widget.videoItem.username,
                description: widget.videoItem.description,
                isBookmarked: false,
                isLiked: _isLiked,
                likeCount: _likeCount,
                commentCount: _commentCount,
                shareCount: widget.videoItem.shareCount,
                onLikeTapped: _toggleLike,
                onPlayPauseTapped: _handleSingleTapCanvas,
                onCommentTapped: _openCommentsSheet,
                onShareTapped: _executeForwardAction,
                isPaused: isCurrentlyPaused,
              );
            },
          )
        else
          VideoFeedViewOverlaySection(
            profileImageUrl: widget.videoItem.profileImageUrl,
            username: widget.videoItem.username,
            description: widget.videoItem.description,
            isBookmarked: false,
            isLiked: _isLiked,
            likeCount: _likeCount,
            commentCount: _commentCount,
            shareCount: widget.videoItem.shareCount,
            onLikeTapped: _toggleLike,
            onPlayPauseTapped: _handleSingleTapCanvas,
            onCommentTapped: _openCommentsSheet,
            onShareTapped: _executeForwardAction,
            isPaused: true,
          ),
      ],
    );
  }
}

class _HeartParticle {
  _HeartParticle({required this.id, required this.position, required this.angle});
  final int id;
  final Offset position;
  final double angle;
}

class _FloatingHeartOverlay extends StatefulWidget {
  const _FloatingHeartOverlay({required this.position, required this.angle, super.key});
  final Offset position;
  final double angle;

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
    const double heartDimensions = 110.0;
    final double adjustedLeft = widget.position.dx - (heartDimensions / 2);
    final double adjustedTop = widget.position.dy - (heartDimensions / 2);

    return Positioned(
      left: adjustedLeft,
      top: adjustedTop,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final double upwardDriftModifier = _animationController.value * -45.0;

          return Transform.translate(
            offset: Offset(0, upwardDriftModifier),
            child: Transform.rotate(
              angle: widget.angle,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFFF0050), 
                    size: heartDimensions,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
