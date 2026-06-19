// Updated: lib/features/video_feed/presentation/view/widgets/video_feed_view_interaction_buttons.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nigergram/features/video_feed/repository/interaction_repository.dart';

/// Interaction stack that now handles optimistic likes and comments via Firestore.
class VideoFeedViewInteractionButtons extends StatefulWidget {
  const VideoFeedViewInteractionButtons({
    required this.videoId,
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    this.isBookmarked = false,
    this.onShareTapped,
    this.onBookmarkTapped,
    super.key,
  });

  final String videoId;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isBookmarked;
  final VoidCallback? onShareTapped;
  final VoidCallback? onBookmarkTapped;

  @override
  State<VideoFeedViewInteractionButtons> createState() => _VideoFeedViewInteractionButtonsState();
}

class _VideoFeedViewInteractionButtonsState extends State<VideoFeedViewInteractionButtons> {
  late bool _isLiked;
  late int _likeCount;
  late int _commentCount;
  final InteractionRepository _repo = InteractionRepository();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;
    _commentCount = widget.commentCount;
  }

  Future<void> _handleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to like')));
      return;
    }

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final newStatus = await _repo.toggleLike(widget.videoId, user.uid);
      // Ensure UI matches backend (in case of race)
      setState(() {
        _isLiked = newStatus;
      });
    } catch (e) {
      // Revert optimistic change on error
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
    }
  }

  Future<void> _handleComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to comment')));
      return;
    }

    final textController = TextEditingController();

    final result = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Write a comment...'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Post Comment'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != true) return; // cancelled

    final commentText = textController.text.trim();
    if (commentText.isEmpty) return;

    // Optimistic update
    setState(() {
      _commentCount += 1;
    });

    try {
      final username = user.displayName ?? user.email?.split('@').first ?? 'user';
      await _repo.addComment(widget.videoId, user.uid, username, commentText);
    } catch (e) {
      // revert
      setState(() => _commentCount -= 1);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like Button
        VideoFeedViewInteractionButton(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(_likeCount),
          iconColor: _isLiked ? const Color(0xFFFE2C55) : Colors.white,
          onTap: _handleLike,
        ),
        SizedBox(height: screenHeight * 0.02),

        // Comment Button
        VideoFeedViewInteractionButton(
          icon: Icons.chat_bubble_rounded,
          label: _formatCount(_commentCount),
          onTap: _handleComment,
        ),
        SizedBox(height: screenHeight * 0.02),

        // Share Button
        VideoFeedViewInteractionButton(
          icon: Icons.reply_rounded,
          label: _formatCount(widget.shareCount),
          onTap: () {
            HapticFeedback.mediumImpact();
            if (widget.onShareTapped != null) widget.onShareTapped!();
          },
        ),
        SizedBox(height: screenHeight * 0.02),

        // Bookmark Button
        VideoFeedViewInteractionButton(
          icon: widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          label: 'Save',
          iconColor: widget.isBookmarked ? Colors.amber : Colors.white,
          onTap: () {
            if (widget.onBookmarkTapped != null) widget.onBookmarkTapped!();
          },
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class VideoFeedViewInteractionButton extends StatefulWidget {
  const VideoFeedViewInteractionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<VideoFeedViewInteractionButton> createState() => _VideoFeedViewInteractionButtonState();
}

class _VideoFeedViewInteractionButtonState extends State<VideoFeedViewInteractionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward().then((_) => _controller.reverse());
        widget.onTap();
      },
      child: Column(
        children: [
          Icon(widget.icon, color: widget.iconColor, size: 28),
          const SizedBox(height: 6),
          Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
