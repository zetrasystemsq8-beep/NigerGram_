import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'comment_item.dart';
import 'comment_composer.dart';
import 'comments_sheet.dart';

/// 🔗 Threaded replies section with smooth expand/collapse animation
/// Features:
/// - SizeTransition for smooth animation
/// - Reply caching to prevent rebuilds
/// - Nested comment composer
/// - Real-time sync with Firestore
class RepliesSection extends StatefulWidget {
  final String videoId;
  final String parentCommentId;
  final CommentData parentComment;
  final Function(int) onReplyCountUpdated;
  final VoidCallback onToggleCollapsed;

  const RepliesSection({
    required this.videoId,
    required this.parentCommentId,
    required this.parentComment,
    required this.onReplyCountUpdated,
    required this.onToggleCollapsed,
    super.key,
  });

  @override
  State<RepliesSection> createState() => _RepliesSectionState();
}

class _RepliesSectionState extends State<RepliesSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandAnimationController;
  late Map<String, CommentData> _replyCache;

  @override
  void initState() {
    super.initState();
    _expandAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimationController.forward();
    _replyCache = {};
  }

  @override
  void dispose() {
    _expandAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Smooth expand/collapse animation
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _expandAnimationController,
        curve: Curves.easeOut,
      ),
      child: Container(
        margin: const EdgeInsets.only(left: 20, top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.grey[300]!,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('videos')
                  .doc(widget.videoId)
                  .collection('comments')
                  .where('parentCommentId', isEqualTo: widget.parentCommentId)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final replies = snapshot.data?.docs ?? [];

                if (replies.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'No replies yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    ...replies.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final replyId = doc.id;
                      if (!_replyCache.containsKey(replyId)) {
                        _replyCache[replyId] =
                            CommentData.fromFirestore(data, replyId);
                      }
                      return RepaintBoundary(
                        key: ValueKey(replyId),
                        child: CommentItem(
                          comment: _replyCache[replyId]!,
                          videoId: widget.videoId,
                          isExpanded: false,
                          onToggleExpanded: () {},
                          onLikeToggled: (_) {},
                          onReplyCountUpdated: (_) {},
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            CommentComposer(
              videoId: widget.videoId,
              parentCommentId: widget.parentCommentId,
              onCommentAdded: (comment) {
                widget.onReplyCountUpdated(
                  widget.parentComment.replyCount + 1,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
