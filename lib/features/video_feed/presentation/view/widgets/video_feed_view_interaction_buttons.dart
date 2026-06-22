import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nigergram/features/video_feed/repository/interaction_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nigergram/features/video_feed/presentation/view/widgets/comments_viewer_bottom_sheet.dart';
import 'package:nigergram/features/wallet/presentation/widgets/tip_bottom_sheet.dart';

/// Production-ready interaction stack with live Firestore & InteractionRepository backend wiring.
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
    this.creatorId,
    this.creatorUsername,
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
  final String? creatorId;
  final String? creatorUsername;

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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _videoSub;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likeCount = widget.likeCount;
    _commentCount = widget.commentCount;

    // Start a real-time listener for the current video so UI stays authoritative
    _startVideoListener(widget.videoId);
  }

  @override
  void didUpdateWidget(covariant VideoFeedViewInteractionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the active video changed, reset local state from incoming props and re-subscribe
    if (oldWidget.videoId != widget.videoId) {
      setState(() {
        _isLiked = widget.isLiked;
        _likeCount = widget.likeCount;
        _commentCount = widget.commentCount;
        _likePending = false;
      });
      _startVideoListener(widget.videoId);
      return;
    }

    // If counts or like flag were updated by parent, reconcile
    if (oldWidget.likeCount != widget.likeCount || oldWidget.commentCount != widget.commentCount || oldWidget.isLiked != widget.isLiked) {
      setState(() {
        _likeCount = widget.likeCount;
        _commentCount = widget.commentCount;
        _isLiked = widget.isLiked;
      });
    }
  }

  void _startVideoListener(String videoId) {
    _stopVideoListener();
    try {
      _videoSub = _firestore.collection('videos').doc(videoId).snapshots().listen((doc) {
        if (!mounted) return;
        final data = doc.data();
        if (data == null) return;

        setState(() {
          _likeCount = (data['likeCount'] as num?)?.toInt() ?? _likeCount;
          _commentCount = (data['commentCount'] as num?)?.toInt() ?? _commentCount;

          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final likes = (data['likes'] as List<dynamic>?)?.cast<String>();
            if (likes != null) {
              _isLiked = likes.contains(currentUser.uid);
            }
          }
        });
      });
    } catch (_) {
      // If listener setup fails, keep optimistic UI — no crash
    }
  }

  void _stopVideoListener() {
    _videoSub?.cancel();
    _videoSub = null;
  }

  // --- BACKEND WIRED LIKE TRANSACTION ---
  Future<void> _handleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like videos')),
      );
      return;
    }

    if (_likePending) return; // Prevent spam taps while processing
    _likePending = true;

    // 1. Optimistic UI update: change instantly on screen for high-speed UX
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });

    try {
      // 2. Execute real Firebase backend transaction via your repository
      final newStatus = await _repo.toggleLike(widget.videoId, user.uid);

      // 3. Reconcile with official Firestore numbers to stay perfectly synchronized
      final doc = await _firestore.collection('videos').doc(widget.videoId).get();
      final authoritativeCount = (doc.data()?['likeCount'] as num?)?.toInt();

      if (mounted) {
        setState(() {
          _isLiked = newStatus;
          if (authoritativeCount != null) {
            _likeCount = authoritativeCount < 0 ? 0 : authoritativeCount;
          }
        });
      }
    } catch (e) {
      // Revert UI automatically if backend transaction fails completely
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
          if (_likeCount < 0) _likeCount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backend connection failed: $e')),
        );
      }
    } finally {
      _likePending = false;
    }
  }

  // --- BACKEND WIRED COMMENTS SECTION ---
  Future<void> _openComments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    // 1. Open the real-time paginated Comments Sheet stream component
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsViewerBottomSheet(videoId: widget.videoId),
    );

    // 2. When the sheet closes, refresh the backend comment badge count instantly
    try {
      final doc = await _firestore.collection('videos').doc(widget.videoId).get();
      final newCount = (doc.data()?['commentCount'] as num?)?.toInt() ?? _commentCount;
      if (mounted) {
        setState(() => _commentCount = newCount);
      }
    } catch (_) {}
  }

  // --- BACKEND WIRED TAG ROUTING ---
  Future<void> _handleTagTap() async {
    try {
      // Fetch matching document tag metadata directly from the video backend
      final doc = await _firestore.collection('videos').doc(widget.videoId).get();
      final data = doc.data();
      if (data == null) return;

      final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];

      // If backend has tags, pick the first one; otherwise use a fallback discovery term
      final tag = tags.isNotEmpty ? tags.first : 'NigerGram';

      if (context.mounted) {
        // Send user directly to the filtered layout router path
        context.push('/discover?tag=$tag');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tag destination: $e')),
      );
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
        SizedBox(height: screenHeight * 0.02),

        // Wallet Button (NEW) - quick access to user's wallet
        VideoFeedViewInteractionButton(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
          onTap: () {
            HapticFeedback.mediumImpact();
            context.push('/wallet');
          },
        ),
        SizedBox(height: screenHeight * 0.02),

        // Tip/Gift Button (opens TipBottomSheet)
        VideoFeedViewInteractionButton(
          icon: Icons.card_giftcard_rounded,
          label: 'Tip',
          onTap: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please sign in to tip creators')),
              );
              return;
            }

            // Fetch creator details if not provided
            String? creatorId = widget.creatorId;
            String? creatorUsername = widget.creatorUsername;
            if (creatorId == null || creatorUsername == null) {
              try {
                final doc = await _firestore.collection('videos').doc(widget.videoId).get();
                final data = doc.data();
                creatorId = data?['creatorId'] as String?;
                creatorUsername = data?['creatorUsername'] as String?;
              } catch (_) {}
            }

            if (creatorId == null || creatorId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Creator information unavailable')),
              );
              return;
            }

            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => TipBottomSheet(
                creatorId: creatorId!,
                creatorUsername: creatorUsername ?? '',
                videoId: widget.videoId,
              ),
            );
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

  @override
  void dispose() {
    _stopVideoListener();
    super.dispose();
  }
}

class VideoFeedViewInteractionButton extends StatelessWidget {
  const VideoFeedViewInteractionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
