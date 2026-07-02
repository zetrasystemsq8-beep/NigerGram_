// lib/features/video_feed/presentation/view/widgets/comments_viewer_bottom_sheet.dart
// 🎬 PASS-THROUGH WRAPPER for TikTok-quality comment experience
// Delegates to CommentsSheet for modular architecture

import 'package:flutter/material.dart';
import 'comments_sheet.dart';

class CommentsViewerBottomSheet extends StatelessWidget {
  final String videoId;

  const CommentsViewerBottomSheet({
    required this.videoId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Delegates to the new modular CommentsSheet
    // This preserves the existing API while using the new architecture internally
    return CommentsSheet(videoId: videoId, initialCommentCount: 0);
  }
}
