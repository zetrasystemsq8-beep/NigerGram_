// lib/features/video_feed/presentation/view/widgets/video_feed_view_item.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nigergram/core/design_system/colors.dart';
import 'package:nigergram/features/video_feed/domain/entities/video_entity.dart';
import 'package:video_player/video_player.dart';
import 'video_feed_view_optimized_video_player.dart';
import 'video_feed_view_interaction_buttons.dart';
import 'comments_viewer_bottom_sheet.dart';
import 'video_share_bottom_sheet.dart';

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

class _VideoFeedViewItemState extends State<VideoFeedViewItem>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  bool _showPlayPause = false;
  late AnimationController _likeAnimationController;
  late AnimationController _heartExplosionController;

  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.videoItem.isLiked ?? false;
    _likeCount = widget.videoItem.likeCount;

    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartExplosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _heartExplosionController.dispose();
    widget.controller?.pause();
    super.dispose();
  }

  void _openCommentsModalSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => CommentsViewerBottomSheet(videoId: widget.videoItem.id),
    );
  }

  void _showShareBottomSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoShareBottomSheet(
        videoId: widget.videoItem.id,
        username: widget.videoItem.username ?? 'User',
        description: widget.videoItem.description ?? '',
      ),
    );
  }

  void _handleLike() async {
    HapticFeedback.mediumImpact();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like')),
      );
      return;
    }

    final bool newLikeState = !_isLiked;
    setState(() {
      _isLiked = newLikeState;
      _likeCount += newLikeState ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });

    if (newLikeState) _heartExplosionController.forward(from: 0);
    _likeAnimationController.forward(from: 0);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoItem.id);
      if (newLikeState) {
        await docRef.update({
          'likeCount': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUser.uid]),
        });
      } else {
        await docRef.update({
          'likeCount': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUser.uid]),
        });
      }
    } catch (e) {
      setState(() {
        _isLiked = !newLikeState;
        _likeCount += newLikeState ? -1 : 1;
        if (_likeCount < 0) _likeCount = 0;
      });
    }
  }

  void _togglePlayPause() {
    if (widget.controller == null) return;
    setState(() {
      _isPlaying = !_isPlaying;
      _showPlayPause = true;
    });
    if (_isPlaying) {
      widget.controller!.play();
    } else {
      widget.controller!.pause();
    }
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showPlayPause = false);
    });
  }

  void _navigateToProfile() {
    context.push('/profile/${widget.videoItem.creatorId}');
  }

  void _handleBookmark() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ EVERYTHING IS NULL-SAFE WITH FALLBACKS
    final String username = widget.videoItem.username ?? 'User';
    final String description = widget.videoItem.description ?? '';
    final String profileImageUrl = widget.videoItem.profileImageUrl ?? '';
    final String soundName = widget.videoItem.soundName ?? '';
    final bool isVerified = widget.videoItem.isVerified ?? false;
    final bool isOwnVideo = widget.videoItem.creatorId == FirebaseAuth.instance.currentUser?.uid;
    final int commentCount = widget.videoItem.commentCount;
    final int shareCount = widget.videoItem.shareCount;
    final bool isBookmarked = widget.videoItem.isBookmarked ?? false;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _handleLike,
      child: Stack(
        children: [
          // LAYER 1: Video Player
          Positioned.fill(
            child: VideoFeedViewOptimizedVideoPlayer(
              controller: widget.controller,
              videoId: widget.videoItem.id,
            ),
          ),

          // LAYER 2: Play/Pause Overlay
          if (_showPlayPause)
            Positioned.fill(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showPlayPause ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

          // LAYER 3: Gradient Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black45,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    stops: [0.0, 0.2, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // LAYER 4: User Info (MINIMAL – NO EXTRA WIDGETS)
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@$username',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: NGColors.verified, size: 16),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (soundName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.music_note_rounded, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            soundName,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // LAYER 5: Action Buttons
          Positioned(
            bottom: 40,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? NGColors.like : Colors.white,
                  count: _likeCount,
                  onTap: _handleLike,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  count: commentCount,
                  onTap: () => _openCommentsModalSheet(context),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  color: Colors.white,
                  count: shareCount,
                  onTap: () => _showShareBottomSheet(context),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  icon: isBookmarked ? Icons.bookmark : Icons.bookmark_outline_rounded,
                  color: isBookmarked ? NGColors.accent : Colors.white,
                  count: 0,
                  onTap: _handleBookmark,
                ),
              ],
            ),
          ),

          // LAYER 6: Heart Explosion
          if (_isLiked)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _heartExplosionController,
                  builder: (context, child) {
                    if (_heartExplosionController.value == 0) {
                      return const SizedBox.shrink();
                    }
                    return CustomPaint(
                      painter: HeartExplosionPainter(
                        progress: _heartExplosionController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                count > 999 ? '${(count / 1000).toStringAsFixed(1)}K' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== HEART EXPLOSION PAINTER ====================
class HeartExplosionPainter extends CustomPainter {
  final double progress;
  HeartExplosionPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * 3.14159 + random * 0.001;
      final distance = 50 + progress * 150;
      final dx = distance * (progress * 2) * (0.6 + 0.4 * (i % 3) / 3) *
          (i.isEven ? 1 : -1) * (0.5 + 0.5 * (i % 2));
      final dy = distance * (progress * 2) * (0.6 + 0.4 * (i % 2) / 2) *
          (i.isOdd ? 1 : -1) * (0.5 + 0.5 * (i % 3));
      final position = center + Offset(dx, dy);
      final size = 12 + progress * 20 * (0.5 + 0.5 * (i % 3) / 3);
      final opacity = 1.0 - progress;
      final color = Colors.red.withOpacity(opacity * 0.8);
      _drawHeart(canvas, position, size, color);
    }
  }

  void _drawHeart(Canvas canvas, Offset position, double size, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    final x = position.dx;
    final y = position.dy;
    final s = size / 20;
    path.moveTo(x, y + s * 5);
    path.cubicTo(
      x - s * 12,
      y - s * 5,
      x - s * 6,
      y - s * 12,
      x,
      y - s * 6,
    );
    path.cubicTo(
      x + s * 6,
      y - s * 12,
      x + s * 12,
      y - s * 5,
      x,
      y + s * 5,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
