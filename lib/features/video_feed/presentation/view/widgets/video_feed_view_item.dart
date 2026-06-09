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

  @override
  void initState() {
    super.initState();
    _likeCount = widget.videoItem.likeCount;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoItem.id)
        .collection('likes')
        .doc(user.uid)
        .get();

    if (mounted) {
      setState(() => _isLiked = doc.exists);
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final videoRef = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoItem.id);

    final likeRef = videoRef.collection('likes').doc(user.uid);

    if (_isLiked) {
      await likeRef.delete();
      await videoRef.update({'likeCount': FieldValue.increment(-1)});
      
      // Safety check: Ensure the user hasn't scrolled away before updating the UI
      if (mounted) {
        setState(() {
          _isLiked = false;
          _likeCount--;
        });
      }
    } else {
      await likeRef.set({'userId': user.uid, 'likedAt': FieldValue.serverTimestamp()});
      await videoRef.update({'likeCount': FieldValue.increment(1)});
      
      // Safety check: Ensure the user hasn't scrolled away before updating the UI
      if (mounted) {
        setState(() {
          _isLiked = true;
          _likeCount++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VideoFeedViewOptimizedVideoPlayer(
          controller: widget.controller,
          videoId: widget.videoItem.id,
        ),
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
