import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'comment_actions_sheet.dart';
import 'replies_section.dart';
import 'comments_sheet.dart';

/// 💬 Reusable comment widget with TikTok-style interactions
/// Features:
/// - Smooth like animation (elastic bounce)
/// - Tap to expand/collapse replies
/// - Long-press for comment actions
/// - Real-time like sync
class CommentItem extends StatefulWidget {
  final CommentData comment;
  final String videoId;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final Function(bool) onLikeToggled;
  final Function(int) onReplyCountUpdated;

  const CommentItem({
    required this.comment,
    required this.videoId,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onLikeToggled,
    required this.onReplyCountUpdated,
    super.key,
  });

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;
  late AnimationController _likeAnimationController;
  bool _likeInProgress = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLikedByCurrentUser;
    _likeCount = widget.comment.likes;
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(CommentItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _isLiked = widget.comment.isLikedByCurrentUser;
      _likeCount = widget.comment.likes;
    }
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  /// ✅ Optimistic like toggle with instant feedback
  /// Animates immediately, then syncs to backend
  Future<void> _toggleLike() async {
    if (_likeInProgress) return;

    final wasLiked = _isLiked;
    final oldLikeCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      _likeInProgress = true;
      if (_isLiked) {
        _likeAnimationController.forward();
      } else {
        _likeAnimationController.reverse();
      }
    });

    widget.onLikeToggled(_isLiked);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final commentRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .doc(widget.comment.id);

      await commentRef.update({
        'likeCount': FieldValue.increment(_isLiked ? 1 : -1),
        'likedBy': _isLiked
            ? FieldValue.arrayUnion([currentUserId])
            : FieldValue.arrayRemove([currentUserId]),
      });
    } catch (e) {
      // Rollback on error
      setState(() {
        _isLiked = wasLiked;
        _likeCount = oldLikeCount;
        if (_isLiked) {
          _likeAnimationController.forward();
        } else {
          _likeAnimationController.reverse();
        }
      });
    } finally {
      if (mounted) {
        setState(() => _likeInProgress = false);
      }
    }
  }

  void _showCommentActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentActionsSheet(
        comment: widget.comment,
        videoId: widget.videoId,
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: GestureDetector(
            onLongPress: _showCommentActions,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserRow(),
                          const SizedBox(height: 6),
                          _buildCommentText(),
                          const SizedBox(height: 8),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                    _buildLikeButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
        // ✅ TikTok-style reply expand indicator
        if (widget.comment.replyCount > 0 && !widget.isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
            child: GestureDetector(
              onTap: widget.onToggleExpanded,
              child: Semantics(
                button: true,
                enabled: true,
                label: 'View ${widget.comment.replyCount} replies',
                child: Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'View ${widget.comment.replyCount} ${widget.comment.replyCount == 1 ? 'reply' : 'replies'}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // ✅ Expanded reply threads
        if (widget.isExpanded)
          RepliesSection(
            videoId: widget.videoId,
            parentCommentId: widget.comment.id,
            parentComment: widget.comment,
            onReplyCountUpdated: widget.onReplyCountUpdated,
            onToggleCollapsed: widget.onToggleExpanded,
          ),
      ],
    );
  }

  Widget _buildAvatar() => CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300],
        backgroundImage: widget.comment.avatarUrl.isNotEmpty
            ? NetworkImage(widget.comment.avatarUrl)
            : null,
        child: widget.comment.avatarUrl.isEmpty
            ? Icon(Icons.person, color: Colors.grey[600], size: 20)
            : null,
      );

  Widget _buildUserRow() => Row(
        children: [
          Flexible(
            child: Text(
              widget.comment.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          if (widget.comment.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified, size: 14, color: Colors.blue)],
          if (widget.comment.isCreator) ...[const SizedBox(width: 4), Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3)),
              child: const Text('Creator', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            )],
          if (widget.comment.isPinned) ...[const SizedBox(width: 4), const Icon(Icons.push_pin, size: 12, color: Colors.amber)],
        ],
      );

  Widget _buildCommentText() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          widget.comment.text,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
      );

  Widget _buildActionButtons() => Row(
        children: [
          Text(
            _formatTime(widget.comment.timestamp),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => widget.onToggleExpanded(),
            child: Semantics(
              button: true,
              enabled: true,
              label: 'Reply to comment',
              child: Text(
                'Reply',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      );

  /// ✅ TikTok-style like button with smooth elastic animation
  Widget _buildLikeButton() => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggleLike,
            child: Semantics(
              button: true,
              enabled: !_likeInProgress,
              label: _isLiked ? 'Unlike comment' : 'Like comment',
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                  CurvedAnimation(
                    parent: _likeAnimationController,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: _isLiked ? Colors.red : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _likeCount > 0 ? _likeCount.toString() : '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
}
