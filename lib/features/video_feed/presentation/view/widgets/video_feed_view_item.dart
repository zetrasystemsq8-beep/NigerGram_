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
import 'comments_viewer_bottom_sheet.dart';

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
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.videoItem.isLiked ?? false;
    _likeCount = widget.videoItem.likeCount;
  }

  @override
  void dispose() {
    widget.controller?.pause();
    super.dispose();
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

  void _handleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final bool newLikeState = !_isLiked;
    setState(() {
      _isLiked = newLikeState;
      _likeCount += newLikeState ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
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
    } catch (_) {}
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsViewerBottomSheet(videoId: widget.videoItem.id),
    );
  }

  void _navigateToProfile() {
    context.push('/profile/${widget.videoItem.creatorId}');
  }

  @override
  Widget build(BuildContext context) {
    final String username = widget.videoItem.username ?? 'User';
    final String description = widget.videoItem.description ?? '';
    final String soundName = widget.videoItem.soundName ?? '';
    final bool isVerified = widget.videoItem.isVerified ?? false;
    final int commentCount = widget.videoItem.commentCount;
    final int shareCount = widget.videoItem.shareCount;

    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _handleLike,
      child: Stack(
        children: [
          // Video Player
          Positioned.fill(
            child: VideoFeedViewOptimizedVideoPlayer(
              controller: widget.controller,
              videoId: widget.videoItem.id,
            ),
          ),

          // Play/Pause Overlay
          if (_showPlayPause)
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),

          // Gradient Overlay
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

          // Username
          Positioned(
            bottom: 100,
            left: 16,
            child: GestureDetector(
              onTap: _navigateToProfile,
              child: Row(
                children: [
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: NGColors.verified, size: 16),
                  ],
                ],
              ),
            ),
          ),

          // Description
          if (description.isNotEmpty)
            Positioned(
              bottom: 76,
              left: 16,
              right: 96,
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

          // Sound Name
          if (soundName.isNotEmpty)
            Positioned(
              bottom: 56,
              left: 16,
              right: 96,
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

          // Action Buttons
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
                  onTap: _openComments,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  color: Colors.white,
                  count: shareCount,
                  onTap: () {},
                ),
              ],
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
