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
import 'video_share_bottom_sheet.dart'; // ✅ NEW IMPORT

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
  final List<GlobalKey> _heartKeys = [];

  // Local state for UI updates
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.videoItem.isLiked ?? false;
    _likeCount = widget.videoItem.likeCount;
    _isFollowing = widget.videoItem.isFollowing ?? false;
    
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartExplosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initializeHeartKeys();
  }

  void _initializeHeartKeys() {
    for (int i = 0; i < 12; i++) {
      _heartKeys.add(GlobalKey());
    }
  }

  @override
  void didUpdateWidget(VideoFeedViewItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state when widget updates
    _isLiked = widget.videoItem.isLiked ?? false;
    _likeCount = widget.videoItem.likeCount;
    _isFollowing = widget.videoItem.isFollowing ?? false;
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _heartExplosionController.dispose();
    super.dispose();
  }

  /// 📥 COMMENTS MODAL
  void _openCommentsModalSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return CommentsViewerBottomSheet(videoId: widget.videoItem.id);
      },
    );
  }

  /// 🔗 OLD SHARE ACTION (keep if needed)
  void _executePlatformShareAction(BuildContext context) {
    HapticFeedback.lightImpact();
    final String shareUrl = "https://nigergram.app/video/${widget.videoItem.id}";
    final String shareText =
        "Check out @${widget.videoItem.username} on NigerGram: $shareUrl";

    try {
      Clipboard.setData(ClipboardData(text: shareText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video link copied to clipboard!'),
          backgroundColor: NGColors.accent,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  /// 🔗 NEW SHARE SHEET (Premium Upgrade)
  void _showShareBottomSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoShareBottomSheet(
        videoId: widget.videoItem.id,
        username: widget.videoItem.username,
        description: widget.videoItem.description,
      ),
    );
  }

  /// ❤️ HANDLE LIKE WITH ANIMATION
  void _handleLike() async {
    HapticFeedback.mediumImpact();
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like')),
      );
      return;
    }

    // Toggle like state locally
    final bool newLikeState = !_isLiked;
    
    // Update local state immediately for UI feedback
    setState(() {
      _isLiked = newLikeState;
      _likeCount += newLikeState ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });

    // Trigger heart explosion on like
    if (newLikeState) {
      _heartExplosionController.forward(from: 0);
    }
    
    // Animate the like button
    _likeAnimationController.forward(from: 0);

    // Update Firebase
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
      debugPrint('Like update error: $e');
      // Revert on error
      setState(() {
        _isLiked = !newLikeState;
        _likeCount += newLikeState ? -1 : 1;
        if (_likeCount < 0) _likeCount = 0;
      });
    }
  }

  /// 🎬 TOGGLE PLAY/PAUSE
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
    
    // Hide play/pause indicator after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showPlayPause = false;
        });
      }
    });
  }

  /// 👤 NAVIGATE TO PROFILE
  void _navigateToProfile() {
    HapticFeedback.lightImpact();
    context.push('/profile/${widget.videoItem.creatorId}');
  }

  /// 🔄 FOLLOW USER
  void _handleFollow() async {
    HapticFeedback.lightImpact();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to follow')),
      );
      return;
    }

    // Update local state immediately
    setState(() {
      _isFollowing = true;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.videoItem.creatorId);
      
      await docRef.update({
        'followers': FieldValue.increment(1),
        'followersList': FieldValue.arrayUnion([currentUser.uid]),
      });
      
      // Also update current user's following list
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);
      
      await userRef.update({
        'following': FieldValue.increment(1),
        'followingList': FieldValue.arrayUnion([widget.videoItem.creatorId]),
      });
    } catch (e) {
      debugPrint('Follow error: $e');
      // Revert on error
      setState(() {
        _isFollowing = false;
      });
    }
  }

  /// 📌 HANDLE BOOKMARK
  void _handleBookmark() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save')),
      );
      return;
    }

    // Note: Bookmark state is handled by InteractionButtons widget
    // This is just a pass-through
    debugPrint('Bookmark toggled for: ${widget.videoItem.id}');
  }

  @override
  Widget build(BuildContext context) {
    final bool isLiked = _isLiked;
    final bool isFollowing = _isFollowing;
    final bool isOwnVideo = widget.videoItem.creatorId == FirebaseAuth.instance.currentUser?.uid;

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

          // LAYER 2: Play/Pause Overlay Indicator
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

          // LAYER 3: Top Gradient Overlay (for visibility)
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

          // LAYER 4: Top Section - Creator Info + Follow
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Profile Avatar
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NGColors.accent,
                        width: 2,
                      ),
                      image: widget.videoItem.profileImageUrl != null &&
                              widget.videoItem.profileImageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(widget.videoItem.profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.videoItem.profileImageUrl == null ||
                            widget.videoItem.profileImageUrl!.isEmpty
                        ? Container(
                            decoration: const BoxDecoration(
                              color: NGColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: NGColors.textMuted,
                              size: 24,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Username + Badges
                Expanded(
                  child: GestureDetector(
                    onTap: _navigateToProfile,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@${widget.videoItem.username}',
                            style: const TextStyle(
                              color: NGColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Verified Badge
                        if (widget.videoItem.isVerified ?? false)
                          const Icon(
                            Icons.verified_rounded,
                            color: NGColors.verified,
                            size: 18,
                          ),
                        const SizedBox(width: 4),
                        // Premium Badge
                        if (widget.videoItem.isPremium ?? false)
                          const Icon(
                            Icons.star_rounded,
                            color: NGColors.premium,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),

                // Follow Button (Emerald Green Accent)
                if (!isFollowing && !isOwnVideo)
                  GestureDetector(
                    onTap: _handleFollow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: NGColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // LAYER 5: Bottom Section - Caption + Hashtags + Sound
          Positioned(
            bottom: 16,
            left: 16,
            right: 96, // Space for action buttons
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Caption with Hashtags
                if (widget.videoItem.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      widget.videoItem.description,
                      style: const TextStyle(
                        color: NGColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Sound/Music Tag
                if (widget.videoItem.soundName != null &&
                    widget.videoItem.soundName!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.music_note_rounded,
                        color: NGColors.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.videoItem.soundName!,
                          style: const TextStyle(
                            color: NGColors.textMuted,
                            fontSize: 13,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // LAYER 6: Right Action Buttons (Overlay on top)
          Positioned(
            bottom: 40,
            right: 12,
            child: VideoFeedViewInteractionButtons(
              videoId: widget.videoItem.id,
              isLiked: isLiked,
              likeCount: _likeCount,
              commentCount: widget.videoItem.commentCount,
              shareCount: widget.videoItem.shareCount,
              isBookmarked: widget.videoItem.isBookmarked ?? false,
              creatorId: widget.videoItem.creatorId,
              creatorUsername: widget.videoItem.username,
              onCommentTapped: () => _openCommentsModalSheet(context),
              onShareTapped: () => _showShareBottomSheet(context), // ✅ UPGRADED
              onBookmarkTapped: () => _handleBookmark(),
            ),
          ),

          // LAYER 7: Heart Explosion Animation (on Double Tap)
          if (isLiked)
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
}

/// 🎨 HEART EXPLOSION PAINTER (Custom Animation)
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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
