// lib/features/video_feed/presentation/view/widgets/video_feed_view_interaction_buttons.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/features/video_feed/repository/interaction_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/comments_viewer_bottom_sheet.dart';

/// Interaction stack that now handles optimistic likes, comments, and tags via Firestore.
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
  bool _likePending = false;

  final InteractionRepository _repo = InteractionRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    if (_likePending) return; // avoid concurrent toggles
    _likePending = true;

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });

    try {
      final newStatus = await _repo.toggleLike(widget.videoId, user.uid);

      // Reconcile like state and count from authoritative source
      try {
        final doc = await _firestore.collection('videos').doc(widget.videoId).get();
        final authoritativeCount = (doc.data()?['likeCount'] as num?)?.toInt();
        if (authoritativeCount != null) {
          setState(() {
            _likeCount = authoritativeCount < 0 ? 0 : authoritativeCount;
            _isLiked = newStatus;
          });
        } else {
          setState(() => _isLiked = newStatus);
        }
      } catch (_) {
        // If fetching authoritative count fails, at least set the boolean
        setState(() => _isLiked = newStatus);
      }
    } catch (e) {
      // Revert optimistic change on error
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
        if (_likeCount < 0) _likeCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
    } finally {
      _likePending = false;
    }
  }

  Future<void> _openComments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to comment')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CommentsViewerBottomSheet(videoId: widget.videoId),
    );

    try {
      final doc = await _firestore.collection('videos').doc(widget.videoId).get();
      final newCount = (doc.data()?['commentCount'] as num?)?.toInt() ?? _commentCount;
      setState(() => _commentCount = newCount);
    } catch (_) {}
  }

  Future<void> _handleTagTap() async {
    try {
      final doc = await _firestore.collection('videos').doc(widget.videoId).get();
      final data = doc.data();
      if (data == null) return;
      final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      if (tags.isEmpty) return;

      // Navigate to discover route with the first tag
      final tag = tags.first;
      if (context.mounted) {
        context.push('/discover?tag=$tag');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load tags: $e')));
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
          onTap: _openComments,
        ),
        SizedBox(height: screenHeight * 0.02),

        // Tag Button
        VideoFeedViewInteractionButton(
          icon: Icons.label_rounded,
          label: 'Tags',
          onTap: _handleTagTap,
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
